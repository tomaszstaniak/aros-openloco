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

# collect-aros has the linker path hardcoded into /Volumes/arosbuild. Without
# that image mounted, CMake's very first compiler check fails to link and
# reports "is not able to compile a simple test program" - which reads like a
# broken toolchain, not a missing mount. Say what it really is, up front.
AROS_LD=/Volumes/arosbuild/toolchain-core-x86_64/x86_64-aros-ld
if [ ! -x "$AROS_LD" ]; then
    echo "$AROS_LD not found - /Volumes/arosbuild is not mounted." >&2
    echo "Mount it first:  hdiutil attach -readonly ~/Work/AROS/aros-build.sparseimage" >&2
    exit 1
fi
[ -d "$WORK_DIR/src" ] || { echo "no work tree - run scripts/bootstrap.sh" >&2; exit 1; }
[ -f "$(abi_deps "$ABI")/lib/libSDL3_static.a" ] || {
    echo "no SDL3 for $ABI - run scripts/build-sdl3.sh $ABI" >&2; exit 1; }

# What the title screen and the log will show. Left to itself, CMake reads the
# commit hash of the work tree bootstrap.sh generates - a number that changes on
# every bootstrap and names neither upstream nor the port, and that has already
# sent one investigation down the wrong path. Name both revisions instead:
#
#   OpenLoco, 7f8c90cf+aros (383e679 on openloco-next+19)
#             ^ upstream      ^ this repository  ^ patch set and patch count
PATCH_COUNT=$(ls "$PATCH_DIR"/*.diff 2>/dev/null | wc -l | tr -d ' ')
VERSION_TAG="$(echo "$UPSTREAM_COMMIT" | cut -c1-8)+aros"
VERSION_BRANCH="$(basename "$PATCH_DIR")+$PATCH_COUNT"
# A build whose work tree carries changes that are in no patch file - a
# diagnostic patch, or something half-written - must say so. Otherwise the
# identifier names 19 patches while 21 are compiled in, which is the same kind
# of quiet wrong number this whole change exists to remove.
if [ -n "$(git -C "$WORK_DIR" status --porcelain 2>/dev/null)" ]; then
    VERSION_BRANCH="$VERSION_BRANCH+dirty"
fi
VERSION_SHA="$(git -C "$PORT_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"

# -S is not optional: without it cmake silently does nothing in this layout.
cmake -S "$WORK_DIR" -B "$BUILD" -G Ninja \
    -DOPENLOCO_VERSION_TAG="$VERSION_TAG" \
    -DOPENLOCO_BRANCH="$VERSION_BRANCH" \
    -DOPENLOCO_COMMIT_SHA1_SHORT="$VERSION_SHA" \
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
    -DCMAKE_BUILD_TYPE=Release \
    -DSTRICT=NO \
    -DOPENLOCO_BUILD_TESTS=NO \
    -DOPENLOCO_USE_CCACHE=NO \
    "$@"

cmake --build "$BUILD" -j "$(sysctl -n hw.ncpu 2>/dev/null || nproc)"

# Keep every build. Backlog item 21 was lost to exactly this: the binary that
# wedged was overwritten by the next build, and a rebuild from the same source
# is not provably the same file. Each result is copied under its own SHA-256
# with a note of where it came from, and nothing here ever deletes one.
OUT="$BUILD/OpenLoco"
if [ -f "$OUT" ]; then
    SHA=$(shasum -a 256 "$OUT" | cut -d' ' -f1)
    ARCHIVE=${AROS_TESTBENCH:-$HOME/Work/AROS}/loco-variants/builds/$SHA
    if [ ! -d "$ARCHIVE" ]; then
        mkdir -p "$ARCHIVE"
        cp "$OUT" "$ARCHIVE/OpenLoco"
        {
            echo "sha256:      $SHA"
            echo "built:       $(date '+%Y-%m-%d %H:%M:%S')"
            echo "abi:         $ABI"
            echo "work commit: $(git -C "$WORK_DIR" rev-parse --short HEAD 2>/dev/null)"
            echo "work dirty:  $(git -C "$WORK_DIR" status --porcelain 2>/dev/null | wc -l | tr -d ' ') file(s)"
            # $PATCH_DIR, not patches/openloco: variant builds use another set,
            # and the hardcoded path reported 19 patches for a 18-patch build.
            echo "patches:     $PATCH_COUNT in $(basename "$PATCH_DIR")"
            echo "port commit: $(git -C "$PORT_ROOT" rev-parse --short HEAD 2>/dev/null)"
            echo "version:     $VERSION_TAG ($VERSION_SHA on $VERSION_BRANCH)"
        } > "$ARCHIVE/BUILD-INFO.txt"
        # The patch set with checksums, not just its directory name: patches
        # are edited, and symlinked sets share files with other variants, so a
        # later edit must not silently change how today's build is reproduced.
        {
            echo "patch set: $PATCH_DIR"
            shasum -a 256 "$PATCH_DIR"/*.diff 2>/dev/null | sed "s|$PATCH_DIR/||"
            echo "upstream:  $UPSTREAM_COMMIT"
        } > "$ARCHIVE/PATCHES.txt"
        echo "archived: $ARCHIVE"
    else
        echo "already archived: $ARCHIVE"
    fi
fi
