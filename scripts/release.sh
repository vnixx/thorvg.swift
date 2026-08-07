#!/usr/bin/env bash
# End-to-end binary SPM release:
#   build XCFramework → zip → checksum → update Package.swift →
#   commit → tag → push → GitHub Release (upload zip) → verify resolve
#
# Usage:
#   ./scripts/release.sh 0.0.1
#   ./scripts/release.sh 0.0.1 --dry-run
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${1:-}"
DRY_RUN=0
if [[ "${2:-}" == "--dry-run" ]] || [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
fi
if [[ -z "$VERSION" || "$VERSION" == "--dry-run" ]]; then
  echo -e "${RED}Usage: ./scripts/release.sh <version> [--dry-run]${NC}"
  exit 1
fi
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo -e "${RED}Version must be semver X.Y.Z (got: $VERSION)${NC}"
  exit 1
fi

TAG="$VERSION"
OWNER_REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "vnixx/thorvg.swift")"
ASSET_NAME="ThorVG.xcframework.zip"
URL="https://github.com/${OWNER_REPO}/releases/download/${TAG}/${ASSET_NAME}"
DIST_DIR="$ROOT/dist"
ZIP_PATH="$DIST_DIR/$ASSET_NAME"

echo -e "${BLUE}Release ${TAG} → ${OWNER_REPO}${NC}"

if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo -e "${RED}Tag ${TAG} already exists locally${NC}"
  exit 1
fi
if gh release view "$TAG" >/dev/null 2>&1; then
  echo -e "${RED}GitHub release ${TAG} already exists${NC}"
  exit 1
fi

# Keep working tree clean except ignored build artifacts
if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
  echo -e "${RED}Working tree has tracked changes. Commit/stash first.${NC}"
  git status --short
  exit 1
fi

echo -e "${YELLOW}[1/6] Build XCFramework${NC}"
./scripts/build_frameworks.sh
[[ -d ThorVG.xcframework ]] || { echo -e "${RED}XCFramework missing${NC}"; exit 1; }

echo -e "${YELLOW}[2/6] Zip + checksum${NC}"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"
# Same zip bytes that will be uploaded to the Release.
ditto -c -k --keepParent ThorVG.xcframework "$ZIP_PATH"
CHECKSUM="$(swift package compute-checksum "$ZIP_PATH")"
echo -e "${GREEN}checksum: ${CHECKSUM}${NC}"
echo -e "${GREEN}url: ${URL}${NC}"

echo -e "${YELLOW}[3/6] Update Package.swift${NC}"
./scripts/update_package_swift.sh "$URL" "$CHECKSUM"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo -e "${YELLOW}Dry run: stopping before commit/push/release${NC}"
  git --no-pager diff Package.swift
  exit 0
fi

echo -e "${YELLOW}[4/6] Commit + tag${NC}"
git add Package.swift
if git diff --cached --quiet; then
  echo -e "${RED}Package.swift unchanged after checksum update${NC}"
  exit 1
fi
git commit -m "$(cat <<EOF
Release ${TAG}

Publish SVG-trimmed ThorVG XCFramework binary SPM package.
EOF
)"

git tag -a "$TAG" -m "ThorVG ${TAG} (SVG / CPU / C API)"

echo -e "${YELLOW}[5/6] Push + GitHub Release${NC}"
git push origin HEAD
git push origin "$TAG"

gh release create "$TAG" "$ZIP_PATH" \
  --title "ThorVG ${TAG}" \
  --notes "$(cat <<EOF
## ThorVG ${TAG}

SVG-focused ThorVG binary for Apple platforms (personal fork of \`thorvg.swift\`; not the official Lottie-oriented package).

### Contents
- Engine: **CPU** software rasterizer
- Loader: **SVG** only (no Lottie / PNG / JPG / WebP / TTF)
- Binding: **C API** (\`thorvg_capi.h\`)
- Platforms: macOS (arm64), iOS (arm64), iOS Simulator (arm64) — Apple Silicon only

### Install

\`\`\`swift
dependencies: [
    .package(url: "https://github.com/${OWNER_REPO}.git", from: "${VERSION}")
]
\`\`\`

\`\`\`swift
import ThorVG
\`\`\`

Checksum: \`${CHECKSUM}\`
EOF
)"

echo -e "${YELLOW}[6/6] Verify SPM resolve${NC}"
VERIFY_DIR="$(mktemp -d)/ThorVGVerify"
mkdir -p "$VERIFY_DIR"
cat > "$VERIFY_DIR/Package.swift" <<EOF
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ThorVGVerify",
    platforms: [.iOS(.v13), .macOS(.v10_15)],
    dependencies: [
        .package(url: "https://github.com/${OWNER_REPO}.git", exact: "${VERSION}")
    ],
    targets: [
        .executableTarget(
            name: "ThorVGVerify",
            dependencies: [
                .product(name: "ThorVG", package: "thorvg.swift")
            ],
            linkerSettings: [.linkedLibrary("c++")]
        )
    ]
)
EOF
mkdir -p "$VERIFY_DIR/Sources/ThorVGVerify"
cat > "$VERIFY_DIR/Sources/ThorVGVerify/main.swift" <<'EOF'
import ThorVG

print("ThorVG binary product resolved OK")
// Touch a C symbol so the linker pulls the static archive.
_ = tvg_engine_init(0)
_ = tvg_engine_term()
EOF

# Give GitHub a moment to serve the asset; clear local fingerprint if we retagged.
rm -f "${HOME}/Library/org.swift.swiftpm/security/fingerprints/thorvg.swift-"*.json 2>/dev/null || true
sleep 3
(
  cd "$VERIFY_DIR"
  swift package resolve
  swift build 2>&1
  swift run 2>&1
)

echo -e "${GREEN}Release ${TAG} published.${NC}"
echo -e "${GREEN}https://github.com/${OWNER_REPO}/releases/tag/${TAG}${NC}"

# Open release page (Chrome / default browser) for visual confirmation
if command -v open >/dev/null; then
  open -a "Google Chrome" "https://github.com/${OWNER_REPO}/releases/tag/${TAG}" 2>/dev/null \
    || open "https://github.com/${OWNER_REPO}/releases/tag/${TAG}"
fi
