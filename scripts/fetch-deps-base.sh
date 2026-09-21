#!/bin/sh
# Build the contrib-base SDL3 used to tell a contrib defect from one of ours.
#
#   scripts/fetch-deps-base.sh [abi]        default abi: abiv11
#
# deps-base/<abi> is SDL3 3.4.12 + contrib's pinned AROS patch + the langinfo
# compile guard, and nothing else. The guard is there only because the ABIv11
# SDK has no <langinfo.h> and the tree does not compile without it; it touches
# the time module, not video. Everything else under patches/dependencies/sdl3-*
# is left out on purpose - that is what the comparison is about.
#
# Reuses the tarball and the contrib diff that scripts/fetch-deps.sh fetched and
# checksummed, so run that first. Backlog item 24.
set -e
. "$(dirname "$0")/env.sh"

ABI=${1:-abiv11}
SRC=$(abi_deps "$ABI")/src
BASE=$PORT_ROOT/deps-base/$ABI

for f in SDL3-3.4.12.tar.gz SDL3-3.4.12-aros.diff; do
    [ -f "$SRC/$f" ] || { echo "missing $SRC/$f - run scripts/fetch-deps.sh $ABI" >&2; exit 1; }
done
got=$(shasum -a 256 "$SRC/SDL3-3.4.12-aros.diff" | cut -c1-16)
[ "$got" = d4ce803bc97a257a ] || { echo "contrib diff checksum $got, expected d4ce803bc97a257a" >&2; exit 1; }

rm -rf "$BASE"
mkdir -p "$BASE/src"
tar xzf "$SRC/SDL3-3.4.12.tar.gz" -C "$BASE/src"
patch -p1 -s -d "$BASE/src/SDL3-3.4.12" < "$SRC/SDL3-3.4.12-aros.diff"
patch -p1 -s -d "$BASE/src/SDL3-3.4.12" < "$PORT_ROOT/patches/dependencies/sdl3-3.4.12-langinfo-guard.diff"
cp -r "$SRC/contrib-sdl3" "$BASE/src/"

python3 "$(dirname "$0")/build-sdl3.py" \
    --deps "$BASE" --toolchain "$(abi_toolchain "$ABI")" --sdk "$(abi_sdk "$ABI")" \
    --build "$PORT_ROOT/build-base/$ABI"
