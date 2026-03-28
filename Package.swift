// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Tokmon",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Tokmon",
            path: "Tokmon"
        )
    ]
)
