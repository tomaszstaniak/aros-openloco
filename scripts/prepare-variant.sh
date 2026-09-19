#!/bin/sh
# Put one build variant onto loco-home.img, from the same starting disk every
# time, and say exactly what was installed.
#
#   scripts/prepare-variant.sh <binary>
#
# For comparing binaries (backlog item 21): restoring loco-home.img from one
# golden copy before each variant means the configuration, saves, logs and
# directory layout the game starts from are identical, so the binary is the
# only thing that differs. A variant is identified by the SHA-256 of the binary
# actually copied, not by a repository commit - two builds of one commit can
# differ, and the wrong file is easy to copy.
set -e
BIN=$1
[ -f "$BIN" ] || { echo "usage: $0 <binary>" >&2; exit 2; }
TB=${AROS_TESTBENCH:-$HOME/Work/AROS}
GOLDEN=$TB/loco-variants/loco-home.golden.img
[ -f "$GOLDEN" ] || { echo "no golden image at $GOLDEN" >&2; exit 1; }
if pgrep -f 'qemu.*aros-loco-hd' >/dev/null; then
    echo "machine loco is running - stop it first" >&2; exit 1
fi

cp "$GOLDEN" "$TB/loco-home.img"
DEV=$(hdiutil attach -nomount -imagekey diskimage-class=CRawDiskImage "$TB/loco-home.img" 2>/dev/null | head -1 | awk '{print $1}')
diskutil mount "${DEV}s1" >/dev/null
cp "$BIN" /Volumes/LOCOHOME/loco/OpenLoco
dot_clean -m /Volumes/LOCOHOME
rm -rf /Volumes/LOCOHOME/.fseventsd
sync
echo "installed: $(shasum -a 256 /Volumes/LOCOHOME/loco/OpenLoco | cut -d' ' -f1)  ($(basename "$BIN"))"
hdiutil detach /Volumes/LOCOHOME >/dev/null 2>&1 || hdiutil detach "$DEV" >/dev/null 2>&1
echo "disk restored from: $(shasum -a 256 "$GOLDEN" | cut -d' ' -f1 | cut -c1-16)…"
