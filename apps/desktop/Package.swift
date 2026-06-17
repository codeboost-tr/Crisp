// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Crisp",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Crisp",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "CrispTests",
            dependencies: ["Crisp"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
