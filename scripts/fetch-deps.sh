#!/bin/sh
# Third-party sources the probes and builds need, staged under deps/<abi>/src.
# They are outside our Git; this script is what makes them reproducible.
#
#   scripts/fetch-deps.sh [abi]        default abi: abiv11
#
# SDL3 is the AROS port's own recipe: upstream 3.4.12 tarball with the patch
# from aros-development-team/contrib/SDL3/main applied, exactly as contrib's
# mmakefile.src does it. That patch applies to that tarball with no fuzz.
set -e
. "$(dirname "$0")/env.sh"

ABI=${1:-abiv11}
SRC=$(abi_deps "$ABI")/src
mkdir -p "$SRC"
cd "$SRC"

SDL3_VER=3.4.12
[ -f "SDL3-$SDL3_VER.tar.gz" ] || curl -fsSL -o "SDL3-$SDL3_VER.tar.gz" \
    "https://www.libsdl.org/release/SDL3-$SDL3_VER.tar.gz"
[ -d "SDL3-$SDL3_VER" ] || {
    tar xzf "SDL3-$SDL3_VER.tar.gz"
    # Pinned to a contrib commit, not `master`: fetching from master meant a
    # re-run could pick up a changed AROS patch silently, and move the base of
    # a comparison under our feet. The checksum makes any drift loud.
    # To update: pick the new commit, fetch, review the diff, change both lines.
    CONTRIB_SDL3_COMMIT=200499623c8be1f65a7567fcb4c8f62b343936e4
    CONTRIB_SDL3_SHA256=d4ce803bc97a257a
    curl -fsSL -o "SDL3-$SDL3_VER-aros.diff" \
        "https://raw.githubusercontent.com/aros-development-team/contrib/$CONTRIB_SDL3_COMMIT/SDL3/main/SDL3-$SDL3_VER-aros.diff"
    got=$(shasum -a 256 "SDL3-$SDL3_VER-aros.diff" | cut -c1-16)
    [ "$got" = "$CONTRIB_SDL3_SHA256" ] || {
        echo "SDL3-$SDL3_VER-aros.diff: checksum $got, expected $CONTRIB_SDL3_SHA256 - refusing" >&2
        exit 1
    }
    patch -p1 -d "SDL3-$SDL3_VER" < "SDL3-$SDL3_VER-aros.diff"
    # Ours on top of contrib's; patches/dependencies says why each exists.
    patch -p1 -d "SDL3-$SDL3_VER" < "$PORT_ROOT/patches/dependencies/sdl3-3.4.12-langinfo-guard.diff"
    patch -p1 -d "SDL3-$SDL3_VER" < "$PORT_ROOT/patches/dependencies/sdl3-3.4.12-aros-hidden-window-framebuffer.diff"
    patch -p1 -d "SDL3-$SDL3_VER" < "$PORT_ROOT/patches/dependencies/sdl3-3.4.12-aros-text-input.diff"
}

# Versions pinned by upstream's thirdparty/CMakeLists.txt. Changing one here
# without changing it there makes every probe result meaningless.
[ -d fmt ] || {
    git clone -q --depth 1 -b 11.1.4 https://github.com/fmtlib/fmt.git fmt
    # ABIv11's libstdc++ is built without _GLIBCXX_USE_WCHAR_T, so std::wstring
    # does not exist there. fmt uses it in one helper OpenLoco never calls.
    # A local patch on the pinned version, NOT a rebuild of the standard library.
    git -C fmt apply "$PORT_ROOT/patches/dependencies/fmt-11.1.4-aros-nowstring.diff"
}
[ -d sfl ]  || git clone -q --depth 1 -b 2.2.0          https://github.com/slavenf/sfl-library.git sfl
[ -d yaml ] || {
    git clone -q --depth 1 -b yaml-cpp-0.9.0 https://github.com/jbeder/yaml-cpp.git yaml
    # Bundled dragonbox takes the least/fast integer types from std; AROS has
    # them only in the global namespace. See the patch header.
    git -C yaml apply "$PORT_ROOT/patches/dependencies/yaml-cpp-0.9.0-aros-stdint.diff"
}

echo "deps for $ABI ready in $SRC"
