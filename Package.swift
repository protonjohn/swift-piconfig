// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-piconfig",
    platforms: [.macOS(.v11), .iOS(.v14)],
    products: [
        .library(
            name: "PiConfig",
            targets: ["PiConfig"]),
        .executable(name: "piconfig-eval", targets: ["PiConfigEval"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMinor(from: "1.2.0")),
        .package(url: "https://github.com/pointfreeco/swift-parsing", .upToNextMinor(from: "0.13.0")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .executableTarget(
            name: "PiConfigEval",
            dependencies: [
                "PiConfig",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]),
        .target(name: "PiConfig",
            dependencies: [
                .product(name: "Parsing", package: "swift-parsing")
            ]),
        .testTarget(
            name: "PiConfigTests",
            dependencies: ["PiConfig", "PiConfigEval"]),
    ]
)
