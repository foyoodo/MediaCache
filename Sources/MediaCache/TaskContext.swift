import Foundation

public struct TaskContext: Sendable {

    let media: Media

    let requestedOffset: Int
    let requestedLength: Int

    var shouldDisregardRequestedLength: Bool = false

    var isByteRangeAccessSupported: Bool = false

    var minChunkSize: Int = 1024 * 512      // 512 KB
    var maxChunkSize: Int = 1024 * 1024 * 4 //   4 MB

    var urlRequest: URLRequest {
        var request = URLRequest(
            url: media.url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 15.0
        )
        request.networkServiceType = .avStreaming

        let range: String
        if shouldDisregardRequestedLength {
            range = "bytes=\(requestedOffset)-"
        } else {
            range = "bytes=\(requestedOffset)-\(requestedOffset + requestedLength - 1)"
        }
        request.setValue(range, forHTTPHeaderField: "Range")

        return request
    }
}

extension TaskContext: Hashable {

    public static func == (lhs: TaskContext, rhs: TaskContext) -> Bool {
        guard lhs.media.url == rhs.media.url,
              lhs.isByteRangeAccessSupported == rhs.isByteRangeAccessSupported
        else { return false }

        if !lhs.isByteRangeAccessSupported { return true }

        if lhs.shouldDisregardRequestedLength,
           lhs.shouldDisregardRequestedLength == rhs.shouldDisregardRequestedLength
        {
            return lhs.requestedOffset == rhs.requestedOffset
        }

        return lhs.requestedOffset == rhs.requestedOffset &&
        lhs.requestedLength == rhs.requestedLength
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(media.url)

        if isByteRangeAccessSupported {
            hasher.combine(requestedOffset)
            if !shouldDisregardRequestedLength {
                hasher.combine(requestedLength)
            }
        }
    }
}
