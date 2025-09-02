// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "IosIAP",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "IosIAP",
            targets: ["IosIAP"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "IosIAP",
            dependencies: [],
            path: "Sources"),
        .testTarget(
            name: "IosIapTests",
            dependencies: ["IosIAP"],
            path: "Tests"),
    ],
    swiftLanguageVersions: [.v5]
)