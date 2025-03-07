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
        .target(
            name: "CLibMaxMindDB",
            path: "Sources/CLibMaxMindDB",
            sources: [
                "libmaxminddb-1.12.1/src/maxminddb.c",
                "libmaxminddb-1.12.1/src/data-pool.c"
            ],
            publicHeadersPath: "libmaxminddb-1.12.1/include"
        )
    ]
) 
