import Foundation

public struct Media: Sendable {

    public let cacheKey: String

    public let url: URL

    public init(cacheKey: String, url: URL) {
        self.cacheKey = cacheKey
        self.url = url
    }

    public init(resource: any Resource) {
        self.cacheKey = resource.cacheKey
        self.url = resource.downloadURL
    }
}

extension Media: Hashable {

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.cacheKey == rhs.cacheKey &&
        lhs.url == rhs.url
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(cacheKey)
        hasher.combine(url)
    }
}
