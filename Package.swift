// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ThorVGSwift",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15)
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
            url: "https://github.com/vnixx/thorvg.swift/releases/download/0.0.1/ThorVG.xcframework.zip",
            checksum: "46a136055cd7180a3ca6fcfbfdc5eb3cce702fe5a5cebd6dac91f5be75f789b5"
        )
    ]
)
