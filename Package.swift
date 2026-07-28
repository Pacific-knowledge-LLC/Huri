// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Huri",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "HuriCore",
            targets: ["HuriCore"]
        ),
        .library(
            name: "HuriInfrastructure",
            targets: ["HuriInfrastructure"]
        ),
        .executable(
            name: "HuriApp",
            targets: ["HuriApp"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/ainame/Swift-WebP.git",
            exact: "0.6.1"
        ),
    ],
    targets: [
        .target(
            name: "HuriCore"
        ),
        .target(
            name: "HuriInfrastructure",
            dependencies: [
                "HuriCore",
                .product(name: "WebP", package: "Swift-WebP"),
            ]
        ),
        .executableTarget(
            name: "HuriApp",
            dependencies: [
                "HuriCore",
                "HuriInfrastructure",
            ]
        ),
        .testTarget(
            name: "HuriCoreTests",
            dependencies: ["HuriCore"]
        ),
        .testTarget(
            name: "HuriInfrastructureTests",
            dependencies: ["HuriInfrastructure"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
