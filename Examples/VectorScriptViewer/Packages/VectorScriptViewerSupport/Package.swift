// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "VectorScriptViewerSupport",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
        .visionOS(.v26),
    ],
    products: [
        .library(name: "VectorScriptViewerSupport", targets: ["VectorScriptViewerSupport"]),
    ],
    dependencies: [
        .package(name: "VectorScript", path: "../../../.."),
    ],
    targets: [
        .target(
            name: "VectorScriptViewerSupport",
            dependencies: [
                .product(name: "VectorScript", package: "VectorScript"),
                .product(name: "VectorScriptRender", package: "VectorScript"),
            ]
        ),
        .testTarget(
            name: "VectorScriptViewerSupportTests",
            dependencies: ["VectorScriptViewerSupport"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
