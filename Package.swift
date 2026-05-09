// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TransitMinute",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "TransitMinuteCore",
            targets: ["TransitMinuteCore"]
        ),
        .executable(
            name: "TransitMinute",
            targets: ["TransitMinute"]
        )
    ],
    targets: [
        .target(
            name: "TransitMinuteCore"
        ),
        .executableTarget(
            name: "TransitMinute",
            dependencies: ["TransitMinuteCore"]
        ),
        .testTarget(
            name: "TransitMinuteCoreTests",
            dependencies: ["TransitMinuteCore"],
            resources: [
                .process("Fixtures")
            ]
        )
    ]
)
