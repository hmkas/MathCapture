// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MathCapture",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", exact: "1.15.0"),
    ],
    targets: [
        .executableTarget(
            name: "MathCapture",
            dependencies: [
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ]
        ),
    ]
)
