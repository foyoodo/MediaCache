// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MediaCache",
    platforms: [
        .iOS(.v14),
        .macOS(.v11),
    ],
    products: [
        .library(name: "MediaCache", targets: ["MediaCache"]),
    ],
    targets: [
        .target(name: "MediaCache"),
        .testTarget(name: "MediaCacheTests", dependencies: ["MediaCache"]),
    ]
)
