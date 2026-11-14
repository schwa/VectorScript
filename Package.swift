// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "VectorScript",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .library(name: "VectorScript", targets: ["VectorScript"]),
    ],
    targets: [
        .target(name: "VectorScript"),
        .testTarget(name: "VectorScriptTests", dependencies: ["VectorScript"]),
    ]
)