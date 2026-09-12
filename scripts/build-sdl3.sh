#!/bin/sh
# Build SDL3 as a static link library for one AROS ABI, outside the AROS build
# system.
#
#   scripts/build-sdl3.sh [abi]        default abi: abiv11
#
# contrib/SDL3/main/mmakefile.src has two targets: SDL3-aros-sharedlib builds
# sdl3.library (needs the mesa linklib and iconv), SDL3-aros-staticlib builds
# libSDL3_static.a from the same FILES list with -DSDL3_AROS_STATIC and no
# extra deps. We reproduce the static one, reading the file list straight out
# of mmakefile.src so it cannot drift from contrib.
#
# Why not the AROS build system: the deadwood ABIv11 tree carries no contrib at
# all. Wiring mainline contrib into it is its own project; this gets us a
# linkable SDL3 today. The shipped port should eventually be contrib's
# sdl3.library, not this.
set -e
. "$(dirname "$0")/env.sh"

ABI=${1:-abiv11}
DEPS=$(abi_deps "$ABI")
SRC=$DEPS/src/SDL3-3.4.12

[ -d "$SRC" ] || { echo "run scripts/fetch-deps.sh $ABI first: $SRC missing" >&2; exit 1; }

# contrib's own sources and recipe for the static entry point.
mkdir -p "$DEPS/src/contrib-sdl3"
for f in SDL3_static.c SDL3_intern.h mmakefile.src; do
    [ -f "$DEPS/src/contrib-sdl3/$f" ] || curl -fsSL -o "$DEPS/src/contrib-sdl3/$f" \
        "https://raw.githubusercontent.com/aros-development-team/contrib/master/SDL3/main/$f"
done

exec python3 "$(dirname "$0")/build-sdl3.py" \
    --deps "$DEPS" --toolchain "$(abi_toolchain "$ABI")" --sdk "$(abi_sdk "$ABI")" \
    --build "$(abi_build "$ABI")"
