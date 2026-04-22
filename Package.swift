// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BriteLog",
    platforms: [
        .macOS("15.0"),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
    ],
    targets: [
        .target(
            name: "BriteLogCore"
        ),
        .target(
            name: "BriteLogOSLogStore",
            dependencies: ["BriteLogCore"]
        ),
        .executableTarget(
            name: "BriteLog",
            dependencies: [
                "BriteLogCore",
                "BriteLogOSLogStore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "BriteLogTests",
            dependencies: [
                "BriteLog",
                "BriteLogCore",
                "BriteLogOSLogStore",
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
