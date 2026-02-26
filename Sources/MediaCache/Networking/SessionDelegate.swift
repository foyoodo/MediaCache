import Foundation
import UniformTypeIdentifiers

final class SessionDelegate: NSObject, @unchecked Sendable {

    var getTask: ((URLSessionTask) -> SessionDataTask?)!
    var removeTask: ((URLSessionTask) -> Void)!
}

// MARK: - URLSessionDataDelegate

extension SessionDelegate: URLSessionDataDelegate {

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: (any Error)?
    ) {
        guard let dataTask = getTask(task) else { return }

        dataTask.didComplete()

        if let error {
            dataTask.continuation?.resume(throwing: error)
            dataTask.continuation = nil
        }

        dataTask.dataContinuation?.finish(throwing: error)
        dataTask.dataContinuation = nil

        removeTask(task)
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse
    ) async -> URLSession.ResponseDisposition
    {
        guard let task = getTask(dataTask) else { return .cancel }

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
        task.continuation = nil

        return .allow
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        guard let task = getTask(dataTask) else { return }

        task.didReceive(data: data)
    }
}
