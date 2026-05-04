// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HueHouse",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "HueHouse", targets: ["HueHouse"])
    ],
    targets: [
        .executableTarget(
            name: "HueHouse",
            path: "Sources/HueHouse"
        )
    ]
)
