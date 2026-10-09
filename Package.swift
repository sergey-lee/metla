// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Metla",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(name: "Metla", path: "Sources/Metla")
    ]
)
