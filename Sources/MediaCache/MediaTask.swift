import Foundation

// Lock-protected box used to hand a SessionDataTask from the synchronous
// continuation body to the synchronous onCancel closure, with no async hop.
final class CancellationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _task: SessionDataTask?

    func set(_ task: SessionDataTask) {
        lock.withLock { _task = task }
    }

    func cancel() {
        lock.withLock { _task }?.cancel()
    }
}

final class MediaTask: @unchecked Sendable {

    private let session: URLSession

    private let media: Media

    private var cache: (any Cache)?

    private var sessionTasks: [Int: SessionDataTask] = [:]

    private let lock = NSLock()

    init(
        session: URLSession,
        media: Media,
        cache: (any Cache)? = nil
    ) {
        self.session = session
        self.media = media
        self.cache = cache
    }

    func task(for task: URLSessionTask) -> SessionDataTask? {
        lock.lock()
        defer { lock.unlock() }
        return sessionTasks[task.taskIdentifier]
    }

    func removeTask(for task: URLSessionTask) {
        lock.lock()
        defer { lock.unlock() }
        sessionTasks[task.taskIdentifier] = nil
    }

    func cancel() {
        lock.lock()
        defer { lock.unlock() }
        sessionTasks.forEach {
            $0.value.continuation?.resume(throwing: CancellationError())
            $0.value.dataContinuation?.finish(throwing: CancellationError())
            $0.value.cancel()
        }
        sessionTasks.removeAll()
    }

    func getContentInfo() async throws -> ContentInfo {
        if let contentInfo = try await cache?.contentInfo(of: media) {
            return contentInfo
        }
        let context = TaskContext(media: media, requestedOffset: 0, requestedLength: 2)
        let box = CancellationBox()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let sessionTask = addTask(for: context, continuation: continuation)
                box.set(sessionTask)
                if Task.isCancelled {
                    sessionTask.cancel()
                }
            }
        } onCancel: {
            box.cancel()
        }
    }

    func getData(using context: TaskContext) async throws -> AsyncThrowingStream<Data, Error> {
        let cachedData = try await cache?.read(
            at: context.requestedOffset,
            length: min(context.requestedLength, context.maxChunkSize),
            of: media
        )
        let box = CancellationBox()
        return await withTaskCancellationHandler {
            AsyncThrowingStream<Data, Error>(bufferingPolicy: .bufferingNewest(1)) { continuation in
                if let cachedData, cachedData.count >= context.minChunkSize || cachedData.count >= context.requestedLength {
                    continuation.yield(cachedData)
                    continuation.finish()
                    return
                }
                let sessionTask = addTask(
                    for: context,
                    cachedData: cachedData,
                    dataContinuation: continuation
                )
                box.set(sessionTask)
                if Task.isCancelled {
                    sessionTask.cancel()
                }
            }
        } onCancel: {
            box.cancel()
        }
    }

    private func addTask(
        for context: TaskContext,
        cachedData data: Data? = nil,
        continuation: CheckedContinuation<ContentInfo, Error>? = nil,
        dataContinuation: AsyncThrowingStream<Data, Error>.Continuation? = nil
    ) -> SessionDataTask
    {
        let resolvedContext: TaskContext

        if let data {
            let dataSize = data.count
            resolvedContext = TaskContext(
                media: context.media,
                requestedOffset: context.requestedOffset + dataSize,
                requestedLength: context.requestedLength - dataSize,
                shouldDisregardRequestedLength: context.shouldDisregardRequestedLength,
                isByteRangeAccessSupported: context.isByteRangeAccessSupported,
                minChunkSize: context.minChunkSize,
                maxChunkSize: context.maxChunkSize
            )
        } else {
            resolvedContext = context
        }

        var urlRequest = resolvedContext.urlRequest
        urlRequest.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        let sessionTask = session.dataTask(with: urlRequest)
        sessionTask.taskDescription = media.cacheKey

        let task = SessionDataTask(
            task: sessionTask,
            context: resolvedContext,
            cachedData: data,
        )
        task.continuation = continuation
        task.dataContinuation = dataContinuation

        lock.lock()
        sessionTasks[sessionTask.taskIdentifier] = task
        lock.unlock()

        task.resume()

        return task
    }
}
