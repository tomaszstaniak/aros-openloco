#!/bin/sh
# Link the libpng + zlib smoke test for one AROS ABI, against the STATIC
# archives — never -lpng/-lz, which are stubs into png.library / z1.library.
#
#   scripts/build-png-smoke.sh [abi]      default abi: abiv11
#
# Link order matters: libpng calls into zlib, so png must precede z.
set -e
. "$(dirname "$0")/env.sh"

ABI=${1:-abiv11}
SDK=$(abi_sdk "$ABI")
BUILD=$(abi_build "$ABI")
OUT=$BUILD/png-smoke
mkdir -p "$BUILD"

"$(abi_toolchain "$ABI")/x86_64-aros-g++" --sysroot="$SDK" \
    -std=c++20 -O2 -I"$SDK/include" \
    "$PORT_ROOT/tests/png-smoke/png-smoke.cpp" \
    -o "$OUT" \
    -L"$SDK/lib" -lpng_nostdio -lz.static -lm

# The point of the whole exercise: prove nothing pulled the stubs back in.
NM=$(abi_toolchain "$ABI")/x86_64-aros-nm
# SysBase and StdlibBase are normal for any AROS program; Z1Base and PNGBase
# are the ones that mean a stub crept back in.
if "$NM" "$OUT" 2>/dev/null | grep -qE "(Z1Base|PNGBase)"; then
    echo "FAIL: $OUT references png.library / z1.library:" >&2
    "$NM" "$OUT" | grep -E "Z1Base|PNGBase" >&2
    exit 1
fi
echo "no z1.library / png.library dependency in the binary"
echo "library bases actually required:"
"$NM" "$OUT" | grep "__aros_libreq_" | sed 's/.*__aros_libreq_/  /' | cut -d. -f1 | sort -u
ls -l "$OUT"
