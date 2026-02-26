import Foundation

public final class SessionDataTask: @unchecked Sendable {

    let task: URLSessionDataTask

    let context: TaskContext

    var continuation: CheckedContinuation<ContentInfo, Error>?

    var dataContinuation: AsyncThrowingStream<Data, Error>.Continuation?

    private let chunk: DataChunk

    private var emittedOffset: Int = 0

    private var isStarted: Bool = false

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
        self.emittedOffset = -(cachedData?.count ?? 0)

        chunk.onChunk = { [weak self] data in
            guard let self else { return }
            dataContinuation?.yield(data)
            onResponseData?(data, context.requestedOffset + emittedOffset)
            emittedOffset += data.count
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
        if isStarted { return }
        isStarted = true
        task.resume()
    }

    public func cancel() {
        task.cancel()
    }
}
