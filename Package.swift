// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Capsule",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "Capsule",
            targets: ["Capsule"])
    ],
    targets: [
        .executableTarget(
            name: "Capsule",
            path: "Sources")
    ]
)
