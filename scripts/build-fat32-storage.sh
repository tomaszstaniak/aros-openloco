#!/bin/sh
# Build the FAT32 storage probe for one AROS ABI.
#
#   scripts/build-fat32-storage.sh [abi]        default abi: abiv11
#
# Plain C on purpose: the question is whether a FAT32 volume on AROS is
# trustworthy storage, and a C++ runtime in the way would only add suspects.
# Four write patterns kept apart plus a verify pass meant for a later boot -
# see tests/fat32-storage/fat32-storage.c for what each does and why.
set -e
. "$(dirname "$0")/env.sh"

ABI=${1:-abiv11}
SDK=$(abi_sdk "$ABI")
BUILD=$(abi_build "$ABI")
OUT=$BUILD/fat32-storage
mkdir -p "$BUILD"

"$(abi_toolchain "$ABI")/x86_64-aros-gcc" --sysroot="$SDK" \
    -std=c11 -O1 -Wall -Wextra -I"$SDK/include" \
    "$PORT_ROOT/tests/fat32-storage/fat32-storage.c" \
    -o "$OUT"

ls -l "$OUT"
