# ThorVG.swift (SVG)

Personal SPM distribution of [ThorVG](https://github.com/thorvg/thorvg) focused on **SVG → bitmap** (CPU raster + C API).

> Not the official [`thorvg/thorvg.swift`](https://github.com/thorvg/thorvg.swift) package (that one is Lottie-oriented).  
> This repo ships a **trimmed XCFramework** via GitHub Releases + `binaryTarget`.

## Install

```swift
dependencies: [
    .package(url: "https://github.com/vnixx/thorvg.swift.git", from: "0.0.1")
]
```

```swift
import ThorVG
// C API from thorvg_capi.h
```

## Trimmed build

Meson options used for the binary:

| Option | Value |
|--------|--------|
| engines | `cpu` |
| loaders | `svg` |
| bindings | `capi` |
| threads | `false` |
| extra | _(empty — no Lottie / OpenMP)_ |

Disabled: GL / WebGPU, Lottie, PNG/JPG/WebP/TTF, tools, tests.

ThorVG source is cloned at build time (`thorvg/` @ **v1.1.0**, gitignored) — not a submodule — so SPM consumers only download `Package.swift` + the Release zip.

Platforms (Apple Silicon only): macOS **arm64**, iOS **arm64**, iOS Simulator **arm64**.

Bump ThorVG by changing `THORVG_TAG` / default `v1.1.0` in `scripts/build_frameworks.sh`.

## Release (workflow_dispatch)

Preferred: GitHub → Actions → **Release XCFramework** → Run workflow → enter version.

Locally (same pipeline):

```bash
brew install meson ninja
./scripts/release.sh 0.0.1
```

Pipeline:

1. Build `ThorVG.xcframework` (meson)
2. Zip + `swift package compute-checksum`
3. Rewrite `Package.swift` `binaryTarget` url/checksum
4. Commit + tag + push
5. `gh release create` and upload the **same** zip
6. Smoke-resolve the package

## Scripts

| Script | Role |
|--------|------|
| `scripts/build_frameworks.sh` | Meson → XCFramework |
| `scripts/update_package_swift.sh` | Patch url/checksum |
| `scripts/release.sh` | Full release automation |

## License

MIT — see `LICENSE`. ThorVG retains its own license under `thorvg/`.
