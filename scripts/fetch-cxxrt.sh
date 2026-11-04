#!/bin/sh
# Put the C++ runtime of the Raspberry Pi build into deps/<abi>/cxxrt.
#
#   scripts/fetch-cxxrt.sh <built cxxrt directory>
#
# The Pi toolchain and SDK have no C++ standard library. libc++, libc++abi and
# libunwind 20.1.0 for this target are built by aros-boxerapp's
# scripts/build-cxx-runtime.sh (LLVM 20.1.0 release tarball plus the AROS
# diffs of tools/crosstools/llvm, every input pinned); this port uses that
# result rather than keeping a second copy of the recipe. The directory given
# must hold its BUILDINFO.txt; every archive is checked against the SHA-256
# recorded there before anything is copied.
set -e
. "$(dirname "$0")/env.sh"
ABI=aros-aarch64-abiv1-raspi
SRC=${1:?usage: scripts/fetch-cxxrt.sh <built cxxrt directory>}
DST=$(abi_deps $ABI)/cxxrt
[ -f "$SRC/BUILDINFO.txt" ] || { echo "$SRC/BUILDINFO.txt missing - not a build-cxx-runtime.sh output" >&2; exit 1; }
grep '^archive ' "$SRC/BUILDINFO.txt" | while read -r _ sha name; do
    got=$(shasum -a 256 "$SRC/lib/$name" | cut -d' ' -f1)
    [ "$got" = "$sha" ] || { echo "$name: sha256 $got, BUILDINFO says $sha - refusing" >&2; exit 1; }
    echo "ok $name"
done
grep -q '^compiler: clang version 20.1.0' "$SRC/BUILDINFO.txt" || {
    echo "$SRC was not built with Clang 20.1.0, the Pi toolchain's compiler - refusing" >&2; exit 1; }
rm -rf "$DST"; mkdir -p "$(dirname "$DST")"
ditto "$SRC" "$DST"
echo "C++ runtime in $DST"
sed -n '1,3p' "$DST/BUILDINFO.txt"
