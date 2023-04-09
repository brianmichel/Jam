// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Jam",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "Jam",
            targets: ["Jam"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0"),
    ],
    targets: [
        .target(
            name: "Jam",
            dependencies: []),
        .testTarget(
            name: "JamTests",
            dependencies: ["Jam"],
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "jamgen",
            dependencies: [
                "Jam",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        )
    ]
)
