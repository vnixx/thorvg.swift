#!/usr/bin/env bash
# Build a Ruyi-oriented ThorVG.xcframework (CPU + SVG + C API only).
# Adapted from official thorvg/thorvg.swift scripts, trimmed for SVG icon rendering.
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

echo -e "${GREEN}Building SVG-trimmed ThorVG XCFramework...${NC}"

if [[ ! -f "$THORVG_DIR/meson.build" ]]; then
  echo -e "${RED}Error: thorvg submodule missing. Run: git submodule update --init --recursive${NC}"
  exit 1
fi

command -v meson >/dev/null || { echo -e "${RED}brew install meson${NC}"; exit 1; }
command -v ninja >/dev/null || { echo -e "${RED}brew install ninja${NC}"; exit 1; }

rm -rf "$BUILD_DIR" "$OUTPUT_DIR" "$TEMP_DIR" "$LIB_DIR"
mkdir -p "$TEMP_DIR" "$LIB_DIR" "$HEADERS_DIR"

IPHONEOS_SDK="$(xcrun --show-sdk-path --sdk iphoneos)"
IPHONESIMULATOR_SDK="$(xcrun --show-sdk-path --sdk iphonesimulator)"
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

MESON_MACOS_ARM=("${MESON_BASE[@]}" -Dsimd=true)
MESON_MACOS_X86=("${MESON_BASE[@]}" -Dsimd=false)
MESON_IOS=("${MESON_BASE[@]}" -Dsimd=false)

create_cross_file() {
  local ARCH=$1 SDK_PATH=$2 PLATFORM=$3 OUTPUT_FILE=$4
  local MIN_VERSION="13.0"
  local TARGET_TRIPLE
  if [[ "$PLATFORM" == "iphonesimulator" ]]; then
    TARGET_TRIPLE="${ARCH}-apple-ios${MIN_VERSION}-simulator"
  else
    TARGET_TRIPLE="${ARCH}-apple-ios${MIN_VERSION}"
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

build_for_platform() {
  local ARCH=$1 PLATFORM=$2 SDK_PATH=$3
  local BUILD_PATH="${BUILD_DIR}/${PLATFORM}-${ARCH}"
  echo -e "${GREEN}Building ${PLATFORM} ${ARCH}...${NC}"

  if [[ "$PLATFORM" == "macosx" ]]; then
    if [[ "$ARCH" == "x86_64" ]]; then
      meson setup "$BUILD_PATH" "$THORVG_DIR" \
        "${MESON_MACOS_X86[@]}" \
        -Dcpp_args="-arch $ARCH" \
        -Dcpp_link_args="-arch $ARCH"
    else
      meson setup "$BUILD_PATH" "$THORVG_DIR" \
        "${MESON_MACOS_ARM[@]}" \
        -Dcpp_args="-arch $ARCH" \
        -Dcpp_link_args="-arch $ARCH"
    fi
  else
    local CROSS_FILE="$BUILD_DIR/cross-${PLATFORM}-${ARCH}.txt"
    create_cross_file "$ARCH" "$SDK_PATH" "$PLATFORM" "$CROSS_FILE"
    meson setup "$BUILD_PATH" "$THORVG_DIR" \
      "${MESON_IOS[@]}" \
      --cross-file="$CROSS_FILE"
  fi

  meson compile -C "$BUILD_PATH"
}

echo -e "${YELLOW}=== macOS ===${NC}"
build_for_platform "arm64" "macosx" ""
build_for_platform "x86_64" "macosx" ""

echo -e "${YELLOW}=== iOS device ===${NC}"
build_for_platform "arm64" "iphoneos" "$IPHONEOS_SDK"

echo -e "${YELLOW}=== iOS simulator ===${NC}"
build_for_platform "arm64" "iphonesimulator" "$IPHONESIMULATOR_SDK"

# Headers / modulemap for all slices
cp "$THORVG_DIR/src/bindings/capi/thorvg_capi.h" "$HEADERS_DIR/"
cat > "$HEADERS_DIR/module.modulemap" << 'EOF'
module ThorVG {
    header "thorvg_capi.h"
    export *
}
EOF

mkdir -p "$TEMP_DIR/libs"
lipo -create \
  "${BUILD_DIR}/macosx-arm64/src/libthorvg-1.a" \
  "${BUILD_DIR}/macosx-x86_64/src/libthorvg-1.a" \
  -output "$TEMP_DIR/libs/libthorvg-macos.a"
cp "${BUILD_DIR}/iphoneos-arm64/src/libthorvg-1.a" "$TEMP_DIR/libs/libthorvg-ios.a"
cp "${BUILD_DIR}/iphonesimulator-arm64/src/libthorvg-1.a" "$TEMP_DIR/libs/libthorvg-iossimulator.a"

echo -e "${YELLOW}=== Creating XCFramework ===${NC}"
rm -rf "$OUTPUT_DIR"
xcodebuild -create-xcframework \
  -library "$TEMP_DIR/libs/libthorvg-macos.a" -headers "$HEADERS_DIR" \
  -library "$TEMP_DIR/libs/libthorvg-ios.a" -headers "$HEADERS_DIR" \
  -library "$TEMP_DIR/libs/libthorvg-iossimulator.a" -headers "$HEADERS_DIR" \
  -output "$OUTPUT_DIR"

# Standalone macOS lib for local hacking
mkdir -p "${LIB_DIR}/include"
cp "$TEMP_DIR/libs/libthorvg-macos.a" "${LIB_DIR}/libthorvg-1.a"
cp "$HEADERS_DIR/thorvg_capi.h" "${LIB_DIR}/include/"
cp "$HEADERS_DIR/module.modulemap" "${LIB_DIR}/include/"

rm -rf "$TEMP_DIR"

echo -e "${GREEN}Done.${NC}"
echo -e "${GREEN}XCFramework: ${OUTPUT_DIR}${NC}"
du -sh "$OUTPUT_DIR"
