// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FLAC2MP3",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "FLAC2MP3",
            path: "Sources/FLAC2MP3",
            resources: [
                .process("../../Resources")
            ]
        )
    ]
)
