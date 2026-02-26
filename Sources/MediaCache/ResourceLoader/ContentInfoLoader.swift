import AVFoundation
import UniformTypeIdentifiers

final class ContentInfoLoader: NSObject, ResourceContentInformationLoader, @unchecked Sendable {

    private let media: Media

    private let queue: DispatchQueue

    private(set) var isByteRangeAccessSupported = false

    var tasks: [AVAssetResourceLoadingRequest: Task<(), Never>] = [:]

    init(media: Media, queue: DispatchQueue) {
        self.media = media
        self.queue = queue
    }

    func loadContentInformation(
        request contentInformationRequest: AVAssetResourceLoadingContentInformationRequest,
        of loadingRequest: AVAssetResourceLoadingRequest
    ) -> Bool
    {
        let task = Task {
            do {
                let contentInfo = try await MediaManager.default.retrieveContentInfo(of: media)
                let contentType = contentInfo.mimeType.map { UTType(mimeType: $0)?.identifier } ?? nil

                isByteRangeAccessSupported = contentInfo.isByteRangeAccessSupported

                try Task.checkCancellation()

                queue.async {
                    contentInformationRequest.contentType = contentType
                    contentInformationRequest.contentLength = contentInfo.contentLength
                    contentInformationRequest.isByteRangeAccessSupported = contentInfo.isByteRangeAccessSupported
                    loadingRequest.finishLoading()
                }
            } catch is CancellationError {
                // do nothing
            } catch {
                queue.async {
                    loadingRequest.finishLoading(with: error)
                }
            }
            queue.async {
                self.tasks.removeValue(forKey: loadingRequest)
            }
        }

        tasks[loadingRequest] = task

        return true
    }
}
