// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "presentation_displays_hig",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(
            name: "presentation-displays-hig",
            targets: ["presentation_displays_hig"]
        )
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "presentation_displays_hig",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            resources: []
        )
    ]
)
