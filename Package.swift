// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "OpenIAP",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "OpenIAP",
            targets: ["OpenIAP"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "OpenIAP",
            dependencies: [],
            path: "Sources"),
        .testTarget(
            name: "OpenIapTests",
            dependencies: ["OpenIAP"],
            path: "Tests"),
    ],
    swiftLanguageVersions: [.v5]
)