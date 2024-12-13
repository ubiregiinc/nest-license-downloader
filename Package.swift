// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "nest-license-downloader",
    platforms: [
        .macOS(.v13),
        .iOS(.v16), // need to use URL(filePath:)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
        .package(url: "https://github.com/mtj0928/swift-async-operations", from: "0.2.2"),
        .package(url: "https://github.com/weichsel/ZIPFoundation", from: "0.9.19")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "nest-license-downloader",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "AsyncOperations", package: "swift-async-operations"),
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ]),
    ]
)
