// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Flocon",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Flocon", path: "Sources/Flocon")
    ]
)
