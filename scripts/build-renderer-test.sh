#!/bin/sh
# Link the SDL3 renderer reproducer and the per-process lifecycle test for one
# AROS ABI, against one SDL3 build.
#
#   scripts/build-renderer-test.sh [abi] [suffix]      default abi: abiv11
#
# Which SDL3 is decided by OPENLOCO_DEPS_ROOT, like every other script here.
# The suffix goes on the binaries' names so two SDL3 builds can be compared in
# one guest boot without one binary overwriting the other:
#
#   scripts/build-renderer-test.sh abiv11 -ours
#   OPENLOCO_DEPS_ROOT=$PWD/deps-base scripts/build-renderer-test.sh abiv11 -base
#
# Run scripts/build-sdl3.sh first; it produces deps/<abi>/lib/libSDL3_static.a.
set -e
. "$(dirname "$0")/env.sh"

ABI=${1:-abiv11}
SUFFIX=${2:-}
DEPS=$(abi_deps "$ABI")
BUILD=$(abi_build "$ABI")
SDK=$(abi_sdk "$ABI")

[ -f "$DEPS/lib/libSDL3_static.a" ] || {
    echo "missing $DEPS/lib/libSDL3_static.a - run scripts/build-sdl3.sh $ABI" >&2
    exit 1
}
mkdir -p "$BUILD"

for prog in sdl3-renderer sdl3-lifecycle; do
    "$(abi_toolchain "$ABI")/x86_64-aros-g++" --sysroot="$SDK" \
        -std=c++20 -O2 \
        -I"$DEPS/include" -I"$SDK/include" \
        "$PORT_ROOT/tests/sdl3-renderer/$prog.cpp" \
        -o "$BUILD/$prog$SUFFIX" \
        -L"$DEPS/lib" -L"$SDK/lib" \
        -lSDL3_static -lGL -liconv -lpthread -lm
    ls -l "$BUILD/$prog$SUFFIX"
done
echo "SDL3 from: $DEPS ($(shasum -a 256 "$DEPS/lib/libSDL3_static.a" | cut -c1-16))"
