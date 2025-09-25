// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "you-up",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "you-up",
            targets: ["you-up"]
        ),
        .executable(
            name: "you-up-cli",
            targets: ["you-up-cli"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "you-up",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency=complete")
            ]
        ),
        .executableTarget(
            name: "you-up-cli",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "you-up"
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency=complete")
            ]
        )
    ]
)
