// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "StorageOptimizer",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "StorageOptimizer",
            path: "Sources/StorageOptimizer"
        )
    ]
)
