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
            checksum: "345aed053b200b9ee2960d88715e948600ffacb17c3973ddee172894a02a0593"
        )
    ]
)
