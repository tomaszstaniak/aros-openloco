#!/bin/sh
# Build the FAT32 overwrite probe for one AROS ABI.
#
#   scripts/build-fat32-overwrite.sh [abi]        default abi: abiv11
#
# Plain C on purpose: the question is whether POSIX O_TRUNC over an existing
# file works on an AROS FAT32 volume, and a C++ runtime in the way would only
# add suspects. See tests/fat32-overwrite/fat32-overwrite.c for what it does
# and why it exists.
set -e
. "$(dirname "$0")/env.sh"

ABI=${1:-abiv11}
SDK=$(abi_sdk "$ABI")
BUILD=$(abi_build "$ABI")
OUT=$BUILD/fat32-overwrite
mkdir -p "$BUILD"

"$(abi_toolchain "$ABI")/x86_64-aros-gcc" --sysroot="$SDK" \
    -std=c11 -O1 -Wall -Wextra -I"$SDK/include" \
    "$PORT_ROOT/tests/fat32-overwrite/fat32-overwrite.c" \
    -o "$OUT"

ls -l "$OUT"
