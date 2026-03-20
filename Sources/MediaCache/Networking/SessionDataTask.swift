import Foundation

public final class SessionDataTask: @unchecked Sendable {

    let task: URLSessionDataTask

    let context: TaskContext

    private let lock = NSLock()

    private var _continuation: CheckedContinuation<ContentInfo, Error>?
    var continuation: CheckedContinuation<ContentInfo, Error>? {
        get { lock.withLock { _continuation } }
        set { lock.withLock { _continuation = newValue } }
    }

    private var _dataContinuation: AsyncThrowingStream<Data, Error>.Continuation?
    var dataContinuation: AsyncThrowingStream<Data, Error>.Continuation? {
        get { lock.withLock { _dataContinuation } }
        set { lock.withLock { _dataContinuation = newValue } }
    }

    private let chunk: DataChunk

    private var _emittedOffset: Int = 0
    var emittedOffset: Int {
        get { lock.withLock { _emittedOffset } }
        set { lock.withLock { _emittedOffset = newValue } }
    }

    private var _isStarted: Bool = false

    var onResponseData: ((Data, Int) -> Void)?

    init(
        task: URLSessionDataTask,
        context: TaskContext,
        cachedData: Data? = nil
    ) {
        self.task = task
        self.context = context
        self.chunk = .init(
            chunkSize: context.minChunkSize,
            bufferCapacity: context.maxChunkSize
        )
        self._emittedOffset = -(cachedData?.count ?? 0)

        chunk.onChunk = { [weak self] data in
            guard let self else { return }
            self.dataContinuation?.yield(data)
            self.onResponseData?(data, context.requestedOffset + self.emittedOffset)
            self.emittedOffset += data.count
        }
        cachedData.map(chunk.append(data:))
    }

    func didReceive(data: Data) {
        chunk.append(data: data)
    }

    func didComplete() {
        chunk.flush()
    }

    public func resume() {
        lock.lock()
        defer { lock.unlock() }
        if _isStarted { return }
        _isStarted = true
        task.resume()
    }

    public func cancel() {
        task.cancel()
    }
}
