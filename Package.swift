// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Raf",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Raf",
            path: "Sources/Raf"
        )
    ]
)
