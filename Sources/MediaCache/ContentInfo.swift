import Foundation

public struct ContentInfo: Sendable {

    public var mimeType: String?

    public var contentLength: Int64

    public var isByteRangeAccessSupported: Bool

    public init(
        mimeType: String?,
        contentLength: Int64,
        isByteRangeAccessSupported: Bool
    ) {
        self.mimeType = mimeType
        self.contentLength = contentLength
        self.isByteRangeAccessSupported = isByteRangeAccessSupported
    }
}
