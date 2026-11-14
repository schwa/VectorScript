// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "VectorScriptViewerSupport",
    platforms: [
        .iOS("27.0"),
        .macOS("27.0"),
        .visionOS("27.0"),
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
            dependencies: [
                "VectorScriptViewerSupport",
                .product(name: "VectorScript", package: "VectorScript"),
                .product(name: "VectorScriptRender", package: "VectorScript"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
