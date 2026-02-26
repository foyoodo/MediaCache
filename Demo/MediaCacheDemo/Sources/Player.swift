import AVFoundation
import Foundation
import MediaCache
import MediaPlayer
import Observation

struct Track: Resource, Identifiable, Hashable, Sendable {

    let cacheKey: String

    var id: String { cacheKey }

    let downloadURL: URL

    let title: String

    let artist: String?

    init(cacheKey: String? = nil, title: String, artist: String? = nil, downloadURL: URL) {
        self.cacheKey = cacheKey ?? downloadURL.absoluteString
        self.downloadURL = downloadURL
        self.title = title
        self.artist = artist
    }
}

@MainActor
@Observable
final class Player {
    static let shared = Player()

    private(set) var resources: [Track] = []

    private(set) var currentIndex: Int?

    private(set) var isPlaying = false

    private(set) var isSwitchingTrack = false

    private(set) var elapsedSeconds: TimeInterval = 0

    private(set) var durationSeconds: TimeInterval = 0

    var currentTrack: Track? {
        guard let currentIndex, resources.indices.contains(currentIndex) else { return nil }
        return resources[currentIndex]
    }

    var canPlayPrevious: Bool {
        guard let currentIndex else { return false }
        return currentIndex > 0
    }

    var canPlayNext: Bool {
        guard let currentIndex else { return false }
        return currentIndex < resources.count - 1
    }

    @ObservationIgnored
    private let avPlayer: AVPlayer

    @ObservationIgnored
    private var timeObserverToken: Any?

    @ObservationIgnored
    private var playbackStateObserver: NSKeyValueObservation?

    @ObservationIgnored
    private var itemEndObserver: NSObjectProtocol?

    @ObservationIgnored
    private let prepareQueue = DispatchQueue(label: "mediaCache.demo.player.prepare", qos: .userInitiated)

    @ObservationIgnored
    private let releaseQueue = DispatchQueue(label: "mediaCache.demo.player.release", qos: .utility)

    @ObservationIgnored
    private var switchGeneration: UInt64 = 0

    init() {
        let player = AVPlayer()
        player.automaticallyWaitsToMinimizeStalling = false
        avPlayer = player

        setupPlaybackObserver()
        setupTimeObserver()
        setupRemoteCommands()
    }

    deinit {
        if let timeObserverToken {
            avPlayer.removeTimeObserver(timeObserverToken)
        }

        if let itemEndObserver {
            NotificationCenter.default.removeObserver(itemEndObserver)
        }

        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.previousTrackCommand.removeTarget(nil)
    }

    func setResources(_ resources: [Track], startAt index: Int = 0, autoplay: Bool = false) {
        self.resources = resources

        guard !resources.isEmpty else {
            avPlayer.replaceCurrentItem(with: nil)
            currentIndex = nil
            isSwitchingTrack = false
            elapsedSeconds = 0
            durationSeconds = 0
            isPlaying = false
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        let safeIndex = resources.indices.contains(index) ? index : 0
        replaceCurrentItem(at: safeIndex, autoplay: autoplay)
    }

    func setResources(_ resources: [any Resource], startAt index: Int = 0, autoplay: Bool = false) {
        let tracks = resources.enumerated().map { offset, resource in
            Track(
                cacheKey: resource.cacheKey,
                title: "Track \(offset + 1)",
                downloadURL: resource.downloadURL
            )
        }
        setResources(tracks, startAt: index, autoplay: autoplay)
    }

    func play(at index: Int) {
        guard resources.indices.contains(index) else { return }

        if currentIndex == index, avPlayer.currentItem != nil {
            play()
            return
        }

        replaceCurrentItem(at: index, autoplay: true)
    }

    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    func play() {
        if avPlayer.currentItem == nil, !resources.isEmpty {
            replaceCurrentItem(at: currentIndex ?? 0, autoplay: true)
            return
        }

        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
        #endif

        avPlayer.play()
        updatePlaybackState()
    }

    func pause() {
        avPlayer.pause()
        updatePlaybackState()
    }

    func previous() {
        guard canPlayPrevious, let currentIndex else { return }
        replaceCurrentItem(at: currentIndex - 1, autoplay: true)
    }

    func next() {
        guard canPlayNext, let currentIndex else { return }
        replaceCurrentItem(at: currentIndex + 1, autoplay: true)
    }

    func seek(to seconds: TimeInterval) {
        guard avPlayer.currentItem != nil else { return }

        let currentDuration = avPlayer.currentItem?.duration.seconds.finiteOrZero ?? durationSeconds
        let clamped: TimeInterval

        if currentDuration > 0 {
            clamped = min(max(seconds, 0), currentDuration)
        } else {
            clamped = max(seconds, 0)
        }

        let target = CMTime(seconds: clamped, preferredTimescale: 600)
        avPlayer.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
        elapsedSeconds = clamped
        updateNowPlayingInfo()
    }

    private func replaceCurrentItem(at index: Int, autoplay: Bool) {
        guard resources.indices.contains(index) else { return }

        let track = resources[index]
        switchGeneration &+= 1
        let generation = switchGeneration
        isSwitchingTrack = true
        currentIndex = index
        elapsedSeconds = 0
        durationSeconds = 0
        updateNowPlayingInfo()
        if autoplay {
            isPlaying = true
            updateNowPlayingInfo()
        }

        prepareQueue.async { [track] in
            let asset = ResourceLoader(resource: track).asset()
            let playerItem = AVPlayerItem(asset: asset)
            playerItem.audioTimePitchAlgorithm = .spectral
            let preparedItem = UncheckedSendable(value: playerItem)

            Task { @MainActor [weak self] in
                guard let self else { return }
                self.finishSwitch(generation: generation, preparedItem: preparedItem, autoplay: autoplay)
            }
        }
    }

    private func finishSwitch(
        generation: UInt64,
        preparedItem: UncheckedSendable<AVPlayerItem>,
        autoplay: Bool
    ) {
        guard generation == switchGeneration else { return }

        isSwitchingTrack = false
        let oldItem = avPlayer.currentItem.map(UncheckedSendable.init(value:))

        observeItemDidPlayToEnd(preparedItem.value)
        avPlayer.replaceCurrentItem(with: preparedItem.value)

        if let oldItem {
            releaseQueue.async {
                _ = oldItem
            }
        }

        if autoplay {
            play()
        } else {
            pause()
        }
    }

    private func setupPlaybackObserver() {
        playbackStateObserver = avPlayer.observe(\.timeControlStatus, options: [.new, .initial]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.updatePlaybackState()
            }
        }
    }

    private func setupTimeObserver() {
        let interval = CMTime(seconds: 1, preferredTimescale: 1)
        timeObserverToken = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshProgressFromPlayer()
            }
        }
    }

    private func refreshProgressFromPlayer() {
        elapsedSeconds = avPlayer.currentTime().seconds.finiteOrZero
        durationSeconds = avPlayer.currentItem?.duration.seconds.finiteOrZero ?? 0
        updateNowPlayingInfo()
    }

    private func observeItemDidPlayToEnd(_ item: AVPlayerItem) {
        if let itemEndObserver {
            NotificationCenter.default.removeObserver(itemEndObserver)
        }

        itemEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.next()
            }
        }
    }

    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.isEnabled = true

        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.play()
            }
            return .success
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pause()
            }
            return .success
        }
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.next()
            }
            return .success
        }
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.previous()
            }
            return .success
        }
    }

    private func updatePlaybackState() {
        isPlaying = avPlayer.timeControlStatus == .playing
        updateNowPlayingInfo()
    }

    private func updateNowPlayingInfo() {
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsedSeconds,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyPlaybackQueueIndex: currentIndex ?? 0,
            MPNowPlayingInfoPropertyPlaybackQueueCount: resources.count,
        ]

        if let artist = track.artist, !artist.isEmpty {
            nowPlayingInfo[MPMediaItemPropertyArtist] = artist
        }

        if durationSeconds > 0 {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = durationSeconds
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}

private struct UncheckedSendable<Value>: @unchecked Sendable {
    let value: Value
}

private extension TimeInterval {
    var finiteOrZero: TimeInterval {
        guard isFinite, !isNaN, self > 0 else { return 0 }
        return self
    }
}
