#!/bin/sh
# Build GNU libiconv 1.19 (contrib's AROS diff applied by fetch-deps.sh) as a
# static library, for an ABI whose SDK has no iconv: the Raspberry Pi.
#
#   scripts/build-iconv.sh [abi]        default abi: aros-aarch64-abiv1-raspi
#
# Writes deps/<abi>/lib/libiconv.a and deps/<abi>/include/iconv.h. Only the
# library is built (lib/), not the iconv program.
set -e
. "$(dirname "$0")/env.sh"
ABI=${1:-aros-aarch64-abiv1-raspi}
DEPS=$(abi_deps "$ABI")
SRC=$DEPS/src/libiconv-1.19
OBJ=$(abi_build "$ABI")/iconv
[ -d "$SRC" ] || { echo "run scripts/fetch-deps.sh $ABI first: $SRC missing" >&2; exit 1; }
case "$ABI" in
    aros-aarch64-abiv1-raspi) HOST=aarch64-unknown-aros ;;
    *) HOST=x86_64-unknown-aros ;;
esac
rm -rf "$OBJ"; mkdir -p "$OBJ" "$DEPS/lib" "$DEPS/include"
cd "$OBJ"
CC=$(abi_cc "$ABI") AR=$(abi_tool "$ABI" ar) RANLIB=$(abi_tool "$ABI" ranlib) \
CFLAGS="-O2 -std=gnu11" \
    "$SRC/configure" --host=$HOST --disable-shared --enable-static \
    --disable-nls --disable-rpath --prefix="$DEPS" > configure.log 2>&1 || {
    tail -30 configure.log >&2; exit 1; }
make -j8 lib/localcharset.h > make.log 2>&1
make -C lib -j8 >> make.log 2>&1 || { tail -30 make.log >&2; exit 1; }
cp lib/.libs/libiconv.a "$DEPS/lib/libiconv.a"
cp include/iconv.h "$DEPS/include/iconv.h"
echo "$DEPS/lib/libiconv.a ($(($(stat -f %z "$DEPS/lib/libiconv.a") / 1024)) KiB)"
