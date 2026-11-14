// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "VectorScript",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
        .visionOS(.v26),
    ],
    products: [
        .library(name: "VectorScript", targets: ["VectorScript"]),
        .library(name: "VectorScriptRender", targets: ["VectorScriptRender"]),
        .library(name: "VectorScriptSwiftUI", targets: ["VectorScriptSwiftUI"]),
        .executable(name: "vectorscript", targets: ["VectorScriptCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
        .package(url: "https://github.com/schwa/GoldenImage", .upToNextMinor(from: "0.1.7")),
    ],
    targets: [
        // The format: model, JSON5 coding, path and transform parsers, resolve(). No CoreGraphics.
        .target(name: "VectorScript"),
        .testTarget(name: "VectorScriptTests", dependencies: ["VectorScript"]),
        .target(name: "VectorScriptRender", dependencies: ["VectorScript"]),
        .testTarget(
            name: "VectorScriptRenderTests",
            dependencies: [
                "VectorScript",
                "VectorScriptRender",
                // Built first so CommandLineTests can run it.
                "VectorScriptCLI",
                .product(name: "GoldenImage", package: "GoldenImage"),
            ]
        ),
        .target(name: "VectorScriptSwiftUI", dependencies: ["VectorScript", "VectorScriptRender"]),
        .testTarget(name: "VectorScriptSwiftUITests", dependencies: ["VectorScript", "VectorScriptSwiftUI"]),
        .executableTarget(
            name: "VectorScriptCLI",
            dependencies: [
                "VectorScript",
                "VectorScriptRender",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
