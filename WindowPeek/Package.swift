// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "WindowPeek",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "WindowPeek", targets: ["WindowPeek"])],
    targets: [
        .target(name: "SwitcherCore"),
        .executableTarget(name: "WindowPeek", dependencies: ["SwitcherCore"]),
        .testTarget(name: "SwitcherCoreTests", dependencies: ["SwitcherCore"])
    ]
)
