import Foundation

open class MediaManager: @unchecked Sendable {

    public static let `default` = MediaManager()

    private var tasks: [String: MediaTask] = [:]

    private let session: URLSession

    private let sessionDelegate: SessionDelegate

    private let lock = NSLock()

    init() {
        sessionDelegate = SessionDelegate()
        session = URLSession(
            configuration: .ephemeral,
            delegate: sessionDelegate,
            delegateQueue: nil
        )

        sessionDelegate.getTask = { [weak self] context in
            self?.task(of: context.media)?.task(for: context)
        }
        sessionDelegate.removeTask = { [weak self] context in
            self?.task(of: context.media)?.removeTask(for: context)
        }
    }

    open func retrieveContentInfo(of media: Media) async throws -> ContentInfo {
        task(of: media)?.cancel()
        return try await addTask(for: media).getContentInfo()
    }

    open func retrieveData(using context: TaskContext) async throws -> AsyncThrowingStream<Data, Error> {
        try await addTask(for: context.media).getData(using: context)
    }

    private func task(of media: Media) -> MediaTask? {
        lock.lock()
        defer { lock.unlock() }
        return tasks[media.cacheKey]
    }

    private func addTask(for media: Media) -> MediaTask {
        lock.lock()
        defer { lock.unlock() }

        if let task = tasks[media.cacheKey] {
            task.increment()
            return task
        }

        let task = MediaTask(session: session, media: media)
        tasks[media.cacheKey] = task
        return task
    }

    public func removeStream(of media: Media) {
        guard let task = task(of: media) else { return }

        if task.decrement() == 0 {
            task.cancel()
            lock.lock()
            tasks.removeValue(forKey: media.cacheKey)
            lock.unlock()
        }
    }
}
