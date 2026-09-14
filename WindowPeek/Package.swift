// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "WindowPeek",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "WindowPeek", targets: ["WindowPeek"])],
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")],
    targets: [
        .target(name: "SwitcherCore"),
        .executableTarget(name: "WindowPeek", dependencies: ["SwitcherCore", .product(name: "Sparkle", package: "Sparkle")],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]),
        .testTarget(name: "SwitcherCoreTests", dependencies: ["SwitcherCore"])
    ]
)
