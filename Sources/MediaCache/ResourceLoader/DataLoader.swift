import AVFoundation

final class DataLoader: NSObject, ResourceDataLoader, @unchecked Sendable {

    private let media: Media

    private let isByteRangeAccessSupported: Bool

    private let queue: DispatchQueue

    private var dataRequest: AVAssetResourceLoadingDataRequest?
    private var loadingRequest: AVAssetResourceLoadingRequest?

    var tasks: [AVAssetResourceLoadingRequest: Task<(), Never>] = [:]

    init(
        media: Media,
        isByteRangeAccessSupported: Bool,
        queue: DispatchQueue
    ) {
        self.media = media
        self.isByteRangeAccessSupported = isByteRangeAccessSupported
        self.queue = queue
    }

    func loadData(
        request dataRequest: AVAssetResourceLoadingDataRequest,
        of loadingRequest: AVAssetResourceLoadingRequest
    ) -> Bool
    {
        let requestedOffset = Int(dataRequest.requestedOffset)
        let requestedLength = dataRequest.requestedLength

        self.dataRequest = dataRequest
        self.loadingRequest = loadingRequest

        let task = Task {
            do {
                let context = TaskContext(
                    media: media,
                    requestedOffset: requestedOffset,
                    requestedLength: requestedLength,
                    shouldDisregardRequestedLength: dataRequest.requestsAllDataToEndOfResource,
                    isByteRangeAccessSupported: isByteRangeAccessSupported
                )
                let dataStream = try await MediaManager.default.retrieveData(using: context)
                for try await data in dataStream {
                    try Task.checkCancellation()
                    queue.async {
                        dataRequest.respond(with: data)
                    }
                }
                try Task.checkCancellation()
                queue.async {
                    loadingRequest.finishLoading()
                }
            } catch is CancellationError {
                // do nothing
            } catch {
                queue.async {
                    loadingRequest.finishLoading(with: error)
                }
            }
            tasks.removeValue(forKey: loadingRequest)
        }

        tasks[loadingRequest] = task

        return true
    }
}
