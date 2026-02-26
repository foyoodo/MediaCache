// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MediaCacheDemo",
    dependencies: [
        .package(path: "../../"),
        .package(url: "https://github.com/onevcat/Kingfisher.git", .upToNextMajor(from: "8.0.0")),
    ]
)
