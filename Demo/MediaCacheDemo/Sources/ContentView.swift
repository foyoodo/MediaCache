import Foundation
import SwiftUI

struct ContentView: View {
    @State
    private var player = Player.shared

    @State
    private var progressValue: Double = 0

    @State
    private var isDraggingProgress = false

    private let demoResources: [Track] = [
        Track(
            title: "SoundHelix 1",
            artist: "Demo",
            downloadURL: URL(string: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3")!
        ),
        Track(
            title: "SoundHelix 2",
            artist: "Demo",
            downloadURL: URL(string: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3")!
        ),
        Track(
            title: "SoundHelix 3",
            artist: "Demo",
            downloadURL: URL(string: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3")!
        ),
    ]

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                playlistPanel(player)
                    .frame(width: min(max(proxy.size.width * 0.36, 250), 360))

                Divider()

                playerPanel(player)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            if player.resources.isEmpty {
                player.setResources(demoResources, startAt: 0, autoplay: false)
            }
            syncProgressFromPlayer()
        }
        .onChange(of: player.elapsedSeconds) { _, _ in
            syncProgressFromPlayer()
        }
        .onChange(of: player.durationSeconds) { _, _ in
            syncProgressFromPlayer()
        }
        .onChange(of: player.currentIndex) { _, _ in
            syncProgressFromPlayer()
        }
    }

    @ViewBuilder
    private func playlistPanel(_ player: Player) -> some View {
        List(Array(player.resources.enumerated()), id: \.element.id) { index, track in
            Button {
                player.play(at: index)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(track.title)
                        if let artist = track.artist {
                            Text(artist)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if player.currentIndex == index {
                        Image(systemName: player.isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                            .foregroundStyle(.tint)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(player.isSwitchingTrack)
            .listRowBackground(player.currentIndex == index ? Color.accentColor.opacity(0.1) : Color.clear)
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private func playerPanel(_ player: Player) -> some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)

            VStack(spacing: 8) {
                Text(player.currentTrack?.title ?? "No Track")
                    .font(.title3.weight(.semibold))
                Text(player.currentTrack?.artist ?? "")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if player.isSwitchingTrack {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            VStack(spacing: 8) {
                Slider(
                    value: Binding(
                        get: { progressValue },
                        set: { newValue in
                            progressValue = newValue
                        }
                    ),
                    in: 0...1,
                    onEditingChanged: { editing in
                        isDraggingProgress = editing
                        if !editing {
                            let target = progressValue * player.durationSeconds
                            player.seek(to: target)
                        }
                    }
                )
                .disabled(player.durationSeconds <= 0 || player.isSwitchingTrack)

                HStack {
                    Text(formatTime(displayedElapsedSeconds(for: player)))
                    Spacer()
                    Text(formatTime(player.durationSeconds))
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 28) {
                Button {
                    player.previous()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.title3)
                }
                .disabled(!player.canPlayPrevious || player.isSwitchingTrack)

                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 52))
                }
                .disabled(player.isSwitchingTrack)

                Button {
                    player.next()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                }
                .disabled(!player.canPlayNext || player.isSwitchingTrack)
            }

            Spacer(minLength: 0)
        }
        .padding(24)
    }

    private func displayedElapsedSeconds(for player: Player) -> TimeInterval {
        if isDraggingProgress {
            return progressValue * player.durationSeconds
        }
        return player.elapsedSeconds
    }

    private func syncProgressFromPlayer() {
        guard !isDraggingProgress else { return }

        let duration = max(player.durationSeconds, 0)
        if duration > 0 {
            progressValue = min(max(player.elapsedSeconds / duration, 0), 1)
        } else {
            progressValue = 0
        }
    }

    private func formatTime(_ value: TimeInterval) -> String {
        let totalSeconds = max(0, Int(value.rounded()))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    ContentView()
}
