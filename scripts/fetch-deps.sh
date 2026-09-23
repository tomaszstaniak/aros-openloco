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

# OpenAL, only where the SDK has none. ABIv11's SDK ships libopenal.a - link
# stubs into the shared openal.library 1.16.0 that AROS One installs. Mainline
# has neither the stubs nor the library: its build tree unpacks openal-soft but
# never builds it, and LIBS:openal.library is absent on the pool's v1 machines.
# So there OpenAL is built statically into the game, from the same recipe
# contrib uses for its own libopenal.static.a (MultiMedia/libs/OpenAL), at the
# same contrib commit as SDL3.
if [ ! -f "$(abi_sdk "$ABI")/lib/libopenal.a" ]; then
    OPENAL_VER=1.19.1
    OPENAL_TAR_SHA256=5c2f87ff5188b95e0dc4769719a9d89ce435b8322b4478b95dd4b427fe84b2e9
    CONTRIB_OPENAL_COMMIT=200499623c8be1f65a7567fcb4c8f62b343936e4
    CONTRIB_OPENAL_DIFF_SHA256=505a2c57ad539019
    CONTRIB_OPENAL_CONFIG_SHA256=8e579634a46a0f44
    [ -f "openal-soft-$OPENAL_VER.tar.bz2" ] || curl -fsSL -o "openal-soft-$OPENAL_VER.tar.bz2" \
        "https://openal-soft.org/openal-releases/openal-soft-$OPENAL_VER.tar.bz2"
    got=$(shasum -a 256 "openal-soft-$OPENAL_VER.tar.bz2" | cut -d' ' -f1)
    [ "$got" = "$OPENAL_TAR_SHA256" ] || {
        echo "openal-soft-$OPENAL_VER.tar.bz2: checksum $got - refusing" >&2; exit 1; }
    mkdir -p contrib-openal
    for f in "openal-soft-$OPENAL_VER-aros.diff" config.h; do
        [ -f "contrib-openal/$f" ] || curl -fsSL -o "contrib-openal/$f" \
            "https://raw.githubusercontent.com/aros-development-team/contrib/$CONTRIB_OPENAL_COMMIT/MultiMedia/libs/OpenAL/$f"
    done
    [ "$(shasum -a 256 "contrib-openal/openal-soft-$OPENAL_VER-aros.diff" | cut -c1-16)" = "$CONTRIB_OPENAL_DIFF_SHA256" ] &&
    [ "$(shasum -a 256 contrib-openal/config.h | cut -c1-16)" = "$CONTRIB_OPENAL_CONFIG_SHA256" ] || {
        echo "contrib OpenAL files do not match the pinned checksums - refusing" >&2; exit 1; }
    [ -d "openal-soft-$OPENAL_VER" ] || {
        tar xjf "openal-soft-$OPENAL_VER.tar.bz2"
        patch -p1 -s -d "openal-soft-$OPENAL_VER" < "contrib-openal/openal-soft-$OPENAL_VER-aros.diff"
    }
fi

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
