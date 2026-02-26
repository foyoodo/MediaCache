import Foundation

public protocol Resource {

    var cacheKey: String { get }

    var downloadURL: URL { get }
}

extension URL: Resource {

    public var cacheKey: String { absoluteString }

    public var downloadURL: URL { self }
}
