// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Recorder",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Recorder",
            path: "Sources/Recorder",
            resources: [
                .process("Assets")
            ]
        )
    ]
)
