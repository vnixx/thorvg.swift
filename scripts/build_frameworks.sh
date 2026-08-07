#!/usr/bin/env bash
# Build a Ruyi-oriented ThorVG.xcframework (CPU + SVG + C API only).
# Apple Silicon only: macOS / iOS / tvOS / watchOS / visionOS (+ simulators).
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

THORVG_DIR="thorvg"
BUILD_DIR="build"
OUTPUT_DIR="ThorVG.xcframework"
TEMP_DIR="temp_frameworks"
LIB_DIR="lib"
HEADERS_DIR="${TEMP_DIR}/Headers"

echo -e "${GREEN}Building SVG-trimmed ThorVG XCFramework (arm64, multi-platform)...${NC}"

THORVG_TAG="${THORVG_TAG:-v1.1.0}"
if [[ ! -f "$THORVG_DIR/meson.build" ]]; then
  echo -e "${YELLOW}Cloning thorvg ${THORVG_TAG} (shallow)...${NC}"
  git clone --depth 1 --branch "$THORVG_TAG" https://github.com/thorvg/thorvg.git "$THORVG_DIR"
fi

command -v meson >/dev/null || { echo -e "${RED}brew install meson${NC}"; exit 1; }
command -v ninja >/dev/null || { echo -e "${RED}brew install ninja${NC}"; exit 1; }

rm -rf "$BUILD_DIR" "$OUTPUT_DIR" "$TEMP_DIR" "$LIB_DIR"
mkdir -p "$TEMP_DIR" "$LIB_DIR" "$HEADERS_DIR" "$TEMP_DIR/libs"

XCODE_DEVELOPER_DIR="$(xcode-select -p)"
echo -e "${GREEN}Xcode: ${XCODE_DEVELOPER_DIR}${NC}"

# Ruyi trim: CPU software raster + SVG loader + C API. No Lottie/GL/WebGPU/threads.
MESON_BASE=(
  -Ddefault_library=static
  -Dstatic=true
  -Dloaders=svg
  -Dsavers=
  -Dengines=cpu
  -Dbindings=capi
  -Dtests=false
  -Dtools=
  -Dextra=
  -Dlog=false
  -Dpartial=false
  -Dfile=true
  -Dthreads=false
  -Dbuildtype=release
  -Dstrip=true
)

MESON_MACOS=("${MESON_BASE[@]}" -Dsimd=true)
MESON_APPLE=("${MESON_BASE[@]}" -Dsimd=false)

# PLATFORM|SDK_NAME|MIN_VERSION|TRIPLE_OS|LIB_BASENAME
PLATFORMS=(
  "iphoneos|iphoneos|13.0|ios|ios"
  "iphonesimulator|iphonesimulator|13.0|ios|iossimulator"
  "appletvos|appletvos|13.0|tvos|tvos"
  "appletvsimulator|appletvsimulator|13.0|tvos|tvossimulator"
  "watchos|watchos|7.0|watchos|watchos"
  "watchsimulator|watchsimulator|7.0|watchos|watchossimulator"
  "xros|xros|1.0|xros|xros"
  "xrsimulator|xrsimulator|1.0|xros|xrossimulator"
)

create_cross_file() {
  local ARCH=$1 SDK_PATH=$2 PLATFORM=$3 TRIPLE_OS=$4 MIN_VERSION=$5 OUTPUT_FILE=$6
  local TARGET_TRIPLE
  if [[ "$PLATFORM" == *simulator ]]; then
    TARGET_TRIPLE="${ARCH}-apple-${TRIPLE_OS}${MIN_VERSION}-simulator"
  else
    TARGET_TRIPLE="${ARCH}-apple-${TRIPLE_OS}${MIN_VERSION}"
  fi
  cat > "$OUTPUT_FILE" << EOF
[binaries]
cpp = ['clang++', '-target', '$TARGET_TRIPLE', '-isysroot', '$SDK_PATH']
ar = 'ar'
strip = 'strip'

[properties]
root = '$XCODE_DEVELOPER_DIR'
has_function_printf = true

[built-in options]
cpp_args = []
cpp_link_args = []

[host_machine]
system = 'darwin'
subsystem = 'ios'
kernel = 'xnu'
cpu_family = '$ARCH'
cpu = '$ARCH'
endian = 'little'
EOF
}

build_macos() {
  local ARCH="arm64"
  local BUILD_PATH="${BUILD_DIR}/macosx-${ARCH}"
  echo -e "${GREEN}Building macosx ${ARCH}...${NC}"
  local MAC_MIN="-mmacosx-version-min=10.15"
  meson setup "$BUILD_PATH" "$THORVG_DIR" \
    "${MESON_MACOS[@]}" \
    -Dcpp_args="-arch $ARCH ${MAC_MIN}" \
    -Dcpp_link_args="-arch $ARCH ${MAC_MIN}"
  meson compile -C "$BUILD_PATH"
  cp "${BUILD_PATH}/src/libthorvg-1.a" "$TEMP_DIR/libs/libthorvg-macos.a"
}

build_apple_platform() {
  local PLATFORM=$1 SDK_NAME=$2 MIN_VERSION=$3 TRIPLE_OS=$4 LIB_BASENAME=$5
  local ARCH="arm64"
  local SDK_PATH
  SDK_PATH="$(xcrun --show-sdk-path --sdk "$SDK_NAME")"
  local BUILD_PATH="${BUILD_DIR}/${PLATFORM}-${ARCH}"
  echo -e "${GREEN}Building ${PLATFORM} ${ARCH} (sdk=${SDK_NAME})...${NC}"

  local CROSS_FILE="$BUILD_DIR/cross-${PLATFORM}-${ARCH}.txt"
  mkdir -p "$BUILD_DIR"
  create_cross_file "$ARCH" "$SDK_PATH" "$PLATFORM" "$TRIPLE_OS" "$MIN_VERSION" "$CROSS_FILE"

  meson setup "$BUILD_PATH" "$THORVG_DIR" \
    "${MESON_APPLE[@]}" \
    --cross-file="$CROSS_FILE"
  meson compile -C "$BUILD_PATH"
  cp "${BUILD_PATH}/src/libthorvg-1.a" "$TEMP_DIR/libs/libthorvg-${LIB_BASENAME}.a"
}

echo -e "${YELLOW}=== macOS (arm64) ===${NC}"
build_macos

for entry in "${PLATFORMS[@]}"; do
  IFS='|' read -r PLATFORM SDK_NAME MIN_VERSION TRIPLE_OS LIB_BASENAME <<<"$entry"
  echo -e "${YELLOW}=== ${PLATFORM} (arm64) ===${NC}"
  build_apple_platform "$PLATFORM" "$SDK_NAME" "$MIN_VERSION" "$TRIPLE_OS" "$LIB_BASENAME"
done

cp "$THORVG_DIR/src/bindings/capi/thorvg_capi.h" "$HEADERS_DIR/"
cat > "$HEADERS_DIR/module.modulemap" << 'EOF'
module ThorVG {
    header "thorvg_capi.h"
    export *
}
EOF

echo -e "${YELLOW}=== Creating XCFramework ===${NC}"
rm -rf "$OUTPUT_DIR"
xcodebuild -create-xcframework \
  -library "$TEMP_DIR/libs/libthorvg-macos.a" -headers "$HEADERS_DIR" \
  -library "$TEMP_DIR/libs/libthorvg-ios.a" -headers "$HEADERS_DIR" \
  -library "$TEMP_DIR/libs/libthorvg-iossimulator.a" -headers "$HEADERS_DIR" \
  -library "$TEMP_DIR/libs/libthorvg-tvos.a" -headers "$HEADERS_DIR" \
  -library "$TEMP_DIR/libs/libthorvg-tvossimulator.a" -headers "$HEADERS_DIR" \
  -library "$TEMP_DIR/libs/libthorvg-watchos.a" -headers "$HEADERS_DIR" \
  -library "$TEMP_DIR/libs/libthorvg-watchossimulator.a" -headers "$HEADERS_DIR" \
  -library "$TEMP_DIR/libs/libthorvg-xros.a" -headers "$HEADERS_DIR" \
  -library "$TEMP_DIR/libs/libthorvg-xrossimulator.a" -headers "$HEADERS_DIR" \
  -output "$OUTPUT_DIR"

mkdir -p "${LIB_DIR}/include"
cp "$TEMP_DIR/libs/libthorvg-macos.a" "${LIB_DIR}/libthorvg-1.a"
cp "$HEADERS_DIR/thorvg_capi.h" "${LIB_DIR}/include/"
cp "$HEADERS_DIR/module.modulemap" "${LIB_DIR}/include/"

rm -rf "$TEMP_DIR"

echo -e "${GREEN}Done.${NC}"
echo -e "${GREEN}XCFramework: ${OUTPUT_DIR}${NC}"
du -sh "$OUTPUT_DIR"
find "$OUTPUT_DIR" -name '*.a' -exec lipo -info {} \;
