#!/bin/sh
# Build a throwaway FAT32 disk image for a storage experiment, and check it.
#
#   scripts/make-scratch-image.sh <image> <LABEL> <size-MB> [file-to-copy ...]
#
# The point of a fresh image per case: `fsck_msdos` afterwards then says
# something about THAT case alone. Sharing one volume between cases makes every
# result an argument about which write did it.
#
# macOS writes resource-fork `._*` files while copying onto FAT32, and AROS
# programs then see them as real files, so they are removed before detaching.
# The baseline check at the end is part of the experiment, not decoration: a
# "damaged afterwards" result means nothing without it.
set -e

IMG=$1
LABEL=$2
SIZE=$3
[ -n "$SIZE" ] || { echo "usage: $0 <image> <LABEL> <size-MB> [files...]" >&2; exit 2; }
shift 3

rm -f "$IMG"
dd if=/dev/zero of="$IMG" bs=1m count="$SIZE" 2>/dev/null

DEV=$(hdiutil attach -nomount -imagekey diskimage-class=CRawDiskImage "$IMG" 2>/dev/null | head -1 | awk '{print $1}')
[ -n "$DEV" ] || { echo "could not attach $IMG" >&2; exit 1; }
diskutil partitionDisk "$DEV" MBR MS-DOS "$LABEL" 100% >/dev/null

for f in "$@"; do
    cp "$f" "/Volumes/$LABEL/"
done
dot_clean -m "/Volumes/$LABEL"
rm -rf "/Volumes/$LABEL/.fseventsd"
sync
hdiutil detach "/Volumes/$LABEL" >/dev/null 2>&1 || hdiutil detach "$DEV" >/dev/null 2>&1

DEV=$(hdiutil attach -nomount -imagekey diskimage-class=CRawDiskImage "$IMG" 2>/dev/null | head -1 | awk '{print $1}')
echo "--- $IMG ($LABEL, ${SIZE}M) baseline:"
fsck_msdos -n "${DEV}s1" 2>&1 | sed 's/^/    /'
hdiutil detach "$DEV" >/dev/null 2>&1
