// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MagicSwitch",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MagicSwitch", targets: ["MagicSwitch"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", exact: "2.0.0"),
        .package(url: "https://github.com/sindresorhus/LaunchAtLogin-Modern.git", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "MagicSwitch",
            dependencies: [
                "MagicSwitchCore",
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                .product(name: "LaunchAtLogin", package: "LaunchAtLogin-Modern"),
            ],
            path: "Sources/MagicSwitch",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "MagicSwitchCore",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources/MagicSwitchCore",
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [
                .linkedFramework("IOBluetooth"),
                .linkedFramework("Network"),
            ]
        ),
        .testTarget(
            name: "MagicSwitchTests",
            dependencies: ["MagicSwitchCore"],
            path: "Tests/MagicSwitchTests"
        ),
        .testTarget(
            name: "MagicSwitchCoreTests",
            dependencies: ["MagicSwitchCore"],
            path: "Tests/MagicSwitchCoreTests"
        ),
    ]
)
