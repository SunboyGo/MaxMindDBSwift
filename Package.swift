// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "MaxMindDBSwift",
    platforms: [.iOS(.v12), .macOS(.v10_15)],
    products: [
        .library(
            name: "MaxMindDB",
            targets: ["MaxMindDB", "CLibMaxMindDB"]
        )
    ],
    targets: [
        .target(
            name: "MaxMindDB",
            dependencies: ["CLibMaxMindDB"],
            path: "Sources/MaxMindDBSwift"
        ),
        .target(
            name: "CLibMaxMindDB",
            path: "Sources/CLibMaxMindDB",
            publicHeadersPath: ".",
            cSettings: [
                .headerSearchPath(".")
            ]
        )
    ]
)
