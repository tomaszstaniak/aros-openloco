#!/bin/sh
# Shared paths and the pinned upstream revision. Source this, do not run it.
#
#   . "$(dirname "$0")/env.sh"
#
# Everything below PORT_ROOT that is generated — upstream/, work/, build/,
# deps/ — is outside our Git. Only docs, scripts, toolchains and patches are
# versioned, so the port's own history never mixes with the game's.

PORT_ROOT=$(cd "$(dirname "$0")/.." && pwd)
export PORT_ROOT

# The commit every result in docs/ was produced against. Changing it means
# re-running the probes, not just editing this line.
UPSTREAM_REPO=https://github.com/OpenLoco/OpenLoco.git
UPSTREAM_COMMIT=${OPENLOCO_UPSTREAM_COMMIT:-af445f8dc6632c6341fc7b26c3246685406e6815}
export UPSTREAM_REPO UPSTREAM_COMMIT

# Every path below can be overridden, so a second variant - a newer upstream,
# a different patch set - can be bootstrapped, built and kept **beside** the
# pinned one instead of replacing it. Comparing two builds means having both,
# and the pinned tree stays the reference while a candidate is evaluated:
#
#   OPENLOCO_UPSTREAM_COMMIT=<sha> OPENLOCO_UPSTREAM_DIR=$PORT_ROOT/upstream-next/OpenLoco \
#   OPENLOCO_WORK_DIR=$PORT_ROOT/work-next/OpenLoco \
#   OPENLOCO_PATCH_DIR=$PORT_ROOT/patches/openloco-next \
#   OPENLOCO_BUILD_ROOT=$PORT_ROOT/build-next scripts/bootstrap.sh
UPSTREAM_DIR=${OPENLOCO_UPSTREAM_DIR:-$PORT_ROOT/upstream/OpenLoco}   # read-only, never edited
WORK_DIR=${OPENLOCO_WORK_DIR:-$PORT_ROOT/work/OpenLoco}               # upstream + patches, edit here
PATCH_DIR=${OPENLOCO_PATCH_DIR:-$PORT_ROOT/patches/openloco}
export UPSTREAM_DIR WORK_DIR PATCH_DIR

# ABI names used for build/, deps/ and evidence dirs. Keep them in one place:
# a result that does not say which ABI it came from is not a result.
#   abiv11      AROS One 64-bit, deadwood's ABI  -- primary target
#   mainline-v1 mainline AROS x86_64             -- second target
ABIS="abiv11 mainline-v1"
export ABIS

abi_toolchain() {
    case "$1" in
        abiv11)      echo "${AROS_ABIV11_TOOLCHAIN:-$HOME/Work/AROS/toolchain}" ;;
        mainline-v1) echo "${AROS_MAINLINE_TOOLCHAIN:-/Volumes/arosmain/toolchain-mainline}" ;;
        *) echo "unknown ABI '$1'" >&2; return 1 ;;
    esac
}

abi_sdk() {
    case "$1" in
        abiv11)      echo "${AROS_ABIV11_SDK:-$HOME/Work/AROS/sdk}" ;;
        mainline-v1) echo "${AROS_MAINLINE_SDK:-/Volumes/arosmain/build/bin/pc-x86_64/AROS/Developer}" ;;
        *) echo "unknown ABI '$1'" >&2; return 1 ;;
    esac
}

# A binary built for one ABI does not run on the other and the crash looks like
# a broken startup, not a mismatch. Toolchain, SDK and machine must agree.
abi_deps()  { echo "${OPENLOCO_DEPS_ROOT:-$PORT_ROOT/deps}/$1"; }
abi_build() { echo "${OPENLOCO_BUILD_ROOT:-$PORT_ROOT/build}/$1"; }
