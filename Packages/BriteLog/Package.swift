// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BriteLog",
    platforms: [
        .macOS("15.0"),
    ],
    products: [
        .library(
            name: "BriteLogCLI",
            targets: ["BriteLogCLI"],
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
    ],
    targets: [
        .target(
            name: "BriteLogCore",
        ),
        .target(
            name: "BriteLogOSLogStore",
            dependencies: ["BriteLogCore"],
        ),
        .target(
            name: "BriteLogCLI",
            dependencies: [
                "BriteLogCore",
                "BriteLogOSLogStore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
        ),
        .executableTarget(
            name: "BriteLog",
            dependencies: [
                "BriteLogCLI",
            ],
        ),
        .testTarget(
            name: "BriteLogTests",
            dependencies: [
                "BriteLog",
                "BriteLogCLI",
                "BriteLogCore",
                "BriteLogOSLogStore",
            ],
        ),
    ],
    swiftLanguageModes: [.v6],
)
