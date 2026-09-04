// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacNotch",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "MacNotch",
            targets: ["MacNotch"]
        )
    ],
    targets: [
        .executableTarget(
            name: "MacNotch",
            path: "Sources/MacNotch",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "MacNotchTests",
            dependencies: ["MacNotch"],
            path: "Tests/MacNotchTests"
        )
    ]
)
