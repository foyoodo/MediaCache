import AVFoundation

public protocol ResourceContentInformationLoader {

    func loadContentInformation(
        request contentInformationRequest: AVAssetResourceLoadingContentInformationRequest,
        of loadingRequest: AVAssetResourceLoadingRequest
    ) -> Bool
}

public protocol ResourceDataLoader {

    func loadData(
        request dataRequest: AVAssetResourceLoadingDataRequest,
        of loadingRequest: AVAssetResourceLoadingRequest
    ) -> Bool
}

public final class ResourceLoader: NSObject {

    let media: Media

    let queue = DispatchQueue(label: "mediaCache.resourceLoader.queue")

    public init(media: Media) {
        self.media = media
    }

    public init(resource: any Resource) {
        self.media = .init(resource: resource)
    }

    private lazy var contentInfoLoader = ContentInfoLoader(
        media: media,
        queue: queue
    )

    private lazy var dataLoader = DataLoader(
        media: media,
        isByteRangeAccessSupported: contentInfoLoader.isByteRangeAccessSupported,
        queue: queue
    )
}

// MARK: - AVAssetResourceLoaderDelegate

extension ResourceLoader: AVAssetResourceLoaderDelegate {

    public func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest
    ) -> Bool
    {
        if let contentInformationRequest = loadingRequest.contentInformationRequest {
            return contentInfoLoader.loadContentInformation(
                request: contentInformationRequest,
                of: loadingRequest
            )
        }

        if let dataRequest = loadingRequest.dataRequest {
            return dataLoader.loadData(
                request: dataRequest,
                of: loadingRequest
            )
        }

        return false
    }

    public func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        didCancel loadingRequest: AVAssetResourceLoadingRequest
    ) {
        if let task = dataLoader.tasks[loadingRequest] {
            task.cancel()
            dataLoader.tasks.removeValue(forKey: loadingRequest)
        } else if let task = contentInfoLoader.tasks[loadingRequest] {
            task.cancel()
            contentInfoLoader.tasks.removeValue(forKey: loadingRequest)
        }
    }
}
