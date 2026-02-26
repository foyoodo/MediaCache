import ProjectDescription

let project = Project(
    name: "MediaCacheDemo",
    targets: [
        .target(
            name: "MediaCacheDemo",
            destinations: [.iPhone, .iPad, .mac],
            product: .app,
            bundleId: "com.foyoodo.MediaCacheDemo",
            deploymentTargets: .multiplatform(iOS: "17.0", macOS: "15.0"),
            infoPlist: .default,
            buildableFolders: [
                "MediaCacheDemo/Sources",
                "MediaCacheDemo/Resources",
            ],
            dependencies: [
                .external(name: "MediaCache"),
                .external(name: "Kingfisher"),
            ]
        ),
    ]
)
