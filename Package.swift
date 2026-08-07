// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ThorVG",
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
            checksum: "5de79a113c1c87a70be49a8d30449c9ba2e9a4acc7d8e8c5fc6545b014f76d87"
        )
    ]
)
