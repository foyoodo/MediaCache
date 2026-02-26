import Foundation

public protocol Cache: Sendable {

    func contentInfo(of media: Media) async throws -> ContentInfo?

    func save(contentInfo: ContentInfo, of media: Media) async throws

    func read(at offset: Int, length: Int, of media: Media) async throws -> Data?

    func write(data: Data, at offset: Int, of media: Media) async throws
}
