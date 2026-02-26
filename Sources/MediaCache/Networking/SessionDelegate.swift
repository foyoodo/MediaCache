import Foundation
import UniformTypeIdentifiers

final class SessionDelegate: NSObject, @unchecked Sendable {

    var getTask: ((TaskContext) -> SessionDataTask?)!
    var removeTask: ((TaskContext) -> Void)!
}

// MARK: - URLSessionDataDelegate

extension SessionDelegate: URLSessionDataDelegate {

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: (any Error)?
    ) {
        guard let context = task.taskContext,
              let dataTask = getTask(context)
        else { return }

        dataTask.didComplete()

        if let error {
            dataTask.continuation?.resume(throwing: error)
        }

        dataTask.dataContinuation?.finish(throwing: error)

        removeTask(context)
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse
    ) async -> URLSession.ResponseDisposition
    {
        guard let context = dataTask.taskContext,
              let task = getTask(context)
        else { return .cancel }

        guard let continuation = task.continuation else { return .allow }

        let contentLength: Int64
        let isByteRangeAccessSupported: Bool

        if case let httpResponse as HTTPURLResponse = response {
            contentLength = httpResponse.resolvedExceptedContentLength
            isByteRangeAccessSupported = httpResponse.isByteRangeAccessSupported
        } else {
            contentLength = response.expectedContentLength
            isByteRangeAccessSupported = false
        }

        let contentInfo = ContentInfo(
            mimeType: response.mimeType,
            contentLength: contentLength,
            isByteRangeAccessSupported: isByteRangeAccessSupported
        )

        continuation.resume(returning: contentInfo)

        return .allow
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        guard let context = dataTask.taskContext,
              let task = getTask(context)
        else { return }

        task.didReceive(data: data)
    }
}
