import Foundation

extension HTTPURLResponse {

    var resolvedExceptedContentLength: Int64 {
        let contentRangeKeys = [
            "Content-Range",
            "Content-range",
            "content-Range",
            "content-range",
        ]

        var contentRange: String?
        for key in contentRangeKeys {
            if let range = allHeaderFields[key] as? String {
                contentRange = range
                break
            }
        }

        if let contentRange {
            if let component = contentRange.components(separatedBy: "/").last,
               let contentLength = Int64(component) {
                return contentLength
            }
        }

        return expectedContentLength
    }

    var isByteRangeAccessSupported: Bool {
        // partial content
        if statusCode == 206 { return true }

        let acceptRangesKeys = [
            "Accept-Ranges",
            "Accept-ranges",
            "accept-Ranges",
            "accept-ranges",
        ]

        for key in acceptRangesKeys {
            if let acceptRanges = allHeaderFields[key] as? String {
                return acceptRanges.lowercased() == "bytes" && hasContentRange
            }
        }

        return false
    }

    private var hasContentRange: Bool {
        let contentRangeKeys = [
            "Content-Range",
            "Content-range",
            "content-Range",
            "content-range",
        ]

        for key in contentRangeKeys {
            if let _ = allHeaderFields[key] {
                return true
            }
        }

        return false
    }
}
