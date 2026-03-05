import Foundation

open class MediaManager: @unchecked Sendable {

    public static let `default` = MediaManager()

    private var tasks: [String: MediaTask] = [:]
    private var taskRefCounts: [String: Int] = [:]

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

        sessionDelegate.getTask = { [weak self] sessionTask in
            guard let cacheKey = sessionTask.taskDescription else { return nil }
            return self?.task(forCacheKey: cacheKey)?.task(for: sessionTask)
        }
        sessionDelegate.removeTask = { [weak self] sessionTask in
            guard let cacheKey = sessionTask.taskDescription else { return }
            self?.task(forCacheKey: cacheKey)?.removeTask(for: sessionTask)
        }
    }

    func retainStream(of media: Media) {
        lock.lock()
        defer { lock.unlock() }
        taskRefCounts[media.cacheKey, default: 0] += 1
    }

    open func retrieveContentInfo(of media: Media) async throws -> ContentInfo {
        return try await addTask(for: media).getContentInfo()
    }

    open func retrieveData(using context: TaskContext) async throws -> AsyncThrowingStream<Data, Error> {
        try await addTask(for: context.media).getData(using: context)
    }

    private func task(forCacheKey cacheKey: String) -> MediaTask? {
        lock.lock()
        defer { lock.unlock() }
        return tasks[cacheKey]
    }

    private func addTask(for media: Media) -> MediaTask {
        lock.lock()
        defer { lock.unlock() }

        if let task = tasks[media.cacheKey] {
            return task
        }

        let task = MediaTask(session: session, media: media)
        tasks[media.cacheKey] = task
        return task
    }

    public func removeStream(of media: Media) {
        lock.lock()
        let cacheKey = media.cacheKey

        if let count = taskRefCounts[cacheKey], count > 1 {
            taskRefCounts[cacheKey] = count - 1
            lock.unlock()
            return
        }

        taskRefCounts.removeValue(forKey: cacheKey)
        let task = tasks.removeValue(forKey: cacheKey)
        lock.unlock()

        task?.cancel()
    }
}
