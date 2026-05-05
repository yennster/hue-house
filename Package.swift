// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HueHouse",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .executable(name: "HueHouse", targets: ["HueHouse"]),
        .library(name: "HueKit", targets: ["HueKit"])
    ],
    targets: [
        // Cross-platform core: networking, models, state, parsing, persistence.
        // No AppKit / SwiftUI references — safe to depend on from a future iOS
        // app target without modification.
        .target(
            name: "HueKit",
            path: "Sources/HueKit"
        ),
        // macOS app shell: SwiftUI views, MenuBarExtra, App Intents, AppKit.
        .executableTarget(
            name: "HueHouse",
            dependencies: ["HueKit"],
            path: "Sources/HueHouse"
        ),
        .testTarget(
            name: "HueKitTests",
            dependencies: ["HueKit"],
            path: "Tests/HueKitTests"
        )
    ]
)
