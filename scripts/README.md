# Scripts

## build_frameworks.sh

Builds SVG-trimmed `ThorVG.xcframework` (macOS / iOS / iOS Simulator).

```bash
./scripts/build_frameworks.sh
```

## update_package_swift.sh

```bash
./scripts/update_package_swift.sh "<release-asset-url>" "<checksum>"
```

## release.sh

Full binary SPM release (build → checksum → Package.swift → tag → GitHub Release → verify).

```bash
./scripts/release.sh 0.0.1
./scripts/release.sh 0.0.1 --dry-run
```

Requires: `meson`, `ninja`, `gh` (authenticated), Xcode CLT.
