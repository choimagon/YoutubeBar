// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "YoutubeBar",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "YoutubeBar", targets: ["YoutubeBar"]),
    ],
    targets: [
        .executableTarget(
            name: "YoutubeBar",
            path: "Sources"
        ),
    ]
)
