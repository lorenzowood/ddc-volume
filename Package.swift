// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ddc-volume-control",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "Common",
            path: "Sources/Common"
        ),
        .executableTarget(
            name: "DDCVolumeDaemon",
            dependencies: ["Common"],
            path: "Sources/App"
        ),
        .executableTarget(
            name: "DDCVolumeCLI",
            dependencies: ["Common"],
            path: "Sources/CLI"
        ),
        .testTarget(
            name: "DDCVolumeTests",
            dependencies: ["Common"],
            path: "Tests/DDCVolumeTests"
        ),
    ]
)
