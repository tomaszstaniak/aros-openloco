#!/bin/sh
# Link the SDL3 + std::thread smoke test for one AROS ABI.
#
#   scripts/build-smoke.sh [abi]       default abi: abiv11
#
# Run scripts/build-sdl3.sh first; it produces deps/<abi>/lib/libSDL3_static.a.
set -e
. "$(dirname "$0")/env.sh"

ABI=${1:-abiv11}
DEPS=$(abi_deps "$ABI")
BUILD=$(abi_build "$ABI")
SDK=$(abi_sdk "$ABI")
OUT=$BUILD/sdl3-smoke

[ -f "$DEPS/lib/libSDL3_static.a" ] || {
    echo "missing $DEPS/lib/libSDL3_static.a - run scripts/build-sdl3.sh $ABI" >&2
    exit 1
}
mkdir -p "$BUILD"

"$(abi_toolchain "$ABI")/x86_64-aros-g++" --sysroot="$SDK" \
    -std=c++20 -O2 \
    -I"$DEPS/include" -I"$SDK/include" \
    "$PORT_ROOT/tests/sdl3-smoke/sdl3-smoke.cpp" \
    -o "$OUT" \
    -L"$DEPS/lib" -L"$SDK/lib" \
    -lSDL3_static -lGL -liconv -lpthread -lm

ls -l "$OUT"
