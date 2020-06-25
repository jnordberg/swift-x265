// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "x265",
    platforms: [
        .macOS(.v10_13),
    ],
    products: [
        .library(
            name: "x265",
            targets: ["x265"]
        ),
    ],

    dependencies: [],
    targets: [
        .target(
            name: "x265",
            dependencies: ["libx265"]
        ),
        .systemLibrary(
            name: "libx265",
            pkgConfig: "x265",
            providers: [
                .apt(["libx265-dev"]),
                .brew(["x265"]),
            ]
        ),
        .testTarget(
            name: "x265-tests",
            dependencies: ["x265"]
        ),
    ]
)
