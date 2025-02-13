// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "MaxMindDBSwift",
    platforms: [.iOS(.v12), .macOS(.v10_15)],
    products: [
        .library(
            name: "MaxMindDB",
            targets: ["MaxMindDB"]
        )
    ],
    targets: [
        .target(
            name: "MaxMindDB",
            dependencies: ["CLibMaxMindDB"],
            path: "Sources/MaxMindDBSwift"
        ),
        .binaryTarget(
            name: "CLibMaxMindDB",
            path: "XCFrameworks/MaxMindDBSwift.xcframework"
        )
    ]
)
