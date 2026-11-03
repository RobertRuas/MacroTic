// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "MacroTic",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.4")
    ],
    targets: [
        .executableTarget(
            name: "MacroTic",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-rpath", "-Xlinker", "@executable_path",
                    "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"
                ])
            ]
        )
    ]
)
