// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Photos",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "PhotosApp", targets: ["PhotosApp"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "PhotosApp",
            dependencies: [],
            path: "Sources"
        )
    ]
)
