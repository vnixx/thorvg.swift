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
            checksum: "aadd1cff99f8895541aff4035ab3a5f49b7a2f1e824f6e36886f2bea0a3d0d6a"
        )
    ]
)
