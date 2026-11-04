#!/bin/sh
# Build openal-soft as a static library for an ABI whose SDK has none.
#
#   scripts/build-openal.sh [abi]        default abi: mainline-v1
#
# Mainline and the Raspberry Pi need this; see scripts/build-openal.py for why and how.
# Run scripts/fetch-deps.sh <abi> first.
set -e
. "$(dirname "$0")/env.sh"
ABI=${1:-mainline-v1}
case "$ABI" in aros-aarch64-*) ARCH=aarch64 ;; *) ARCH=x86_64 ;; esac
exec python3 "$(dirname "$0")/build-openal.py" \
    --deps "$(abi_deps "$ABI")" --toolchain "$(abi_toolchain "$ABI")" \
    --sdk "$(abi_sdk "$ABI")" --build "$(abi_build "$ABI")" \
    --cc "$(abi_cc "$ABI")" --ar "$(abi_tool "$ABI" ar)" \
    --arch "$ARCH"
