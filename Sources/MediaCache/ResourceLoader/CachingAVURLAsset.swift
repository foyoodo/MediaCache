import AVFoundation

public final class CachingAVURLAsset: AVURLAsset, @unchecked Sendable {

    private var resourceLoaderDelegate: AVAssetResourceLoaderDelegate?

    fileprivate var onDeinit: (() -> Void)?

    deinit { onDeinit?() }

    func setResourceLoaderDelegate(_ delegate: ResourceLoader?) {
        resourceLoaderDelegate = delegate
        resourceLoader.setDelegate(delegate, queue: delegate?.queue)
    }
}

extension ResourceLoader {

    public func asset() -> AVURLAsset {
        MediaManager.default.retainStream(of: media)

        let asset = CachingAVURLAsset(
            url: media.url.replacingScheme(with: "mediacaching"),
            options: nil
        )
        asset.setResourceLoaderDelegate(self)
        asset.onDeinit = { [media] in
            MediaManager.default.removeStream(of: media)
        }
        return asset
    }
}
