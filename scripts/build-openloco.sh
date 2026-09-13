#!/bin/sh
# Configure and build OpenLoco itself for one AROS ABI.
#
#   scripts/build-openloco.sh [abi]        default abi: abiv11
#
# Prerequisites: scripts/bootstrap.sh, scripts/fetch-deps.sh <abi>,
# scripts/build-sdl3.sh <abi>. The toolchain file points find_package at our
# own SDL3 package and at the STATIC png/zlib archives, so nothing here picks
# up the SDK's link stubs.
#
# STRICT=NO on purpose: upstream turns -Werror on, and warnings from a
# different compiler generation are not defects in this port. Tests are off
# because they need GTest for the target.
set -e
. "$(dirname "$0")/env.sh"

ABI=${1:-abiv11}
BUILD=$(abi_build "$ABI")/openloco
TOOLCHAIN=$PORT_ROOT/toolchains/$ABI.cmake

[ -f "$TOOLCHAIN" ] || { echo "no toolchain file $TOOLCHAIN" >&2; exit 1; }
[ -d "$WORK_DIR/src" ] || { echo "no work tree - run scripts/bootstrap.sh" >&2; exit 1; }
[ -f "$(abi_deps "$ABI")/lib/libSDL3_static.a" ] || {
    echo "no SDL3 for $ABI - run scripts/build-sdl3.sh $ABI" >&2; exit 1; }

# -S is not optional: without it cmake silently does nothing in this layout.
cmake -S "$WORK_DIR" -B "$BUILD" -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
    -DCMAKE_BUILD_TYPE=Release \
    -DSTRICT=NO \
    -DOPENLOCO_BUILD_TESTS=NO \
    -DOPENLOCO_USE_CCACHE=NO \
    "$@"

cmake --build "$BUILD" -j "$(sysctl -n hw.ncpu 2>/dev/null || nproc)"
