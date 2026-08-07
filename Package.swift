// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ThorVG",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v7),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "ThorVG",
            targets: ["ThorVG"]
        )
    ],
    targets: [
        // SVG-focused ThorVG binary (CPU + SVG + C API).
        // URL / checksum are rewritten by scripts/release.sh on each release.
        .binaryTarget(
            name: "ThorVG",
            url: "https://github.com/vnixx/thorvg.swift/releases/download/0.0.2/ThorVG.xcframework.zip",
            checksum: "fb36a9cec20d54fa42f78c7d09527b773389a83cd76882dc25599e24b8f95287"
        )
    ]
)
