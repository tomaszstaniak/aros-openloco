#!/bin/zsh
# Launch machine `loco`: AROS One 64-bit (ABIv11) on its OWN copy of the disk,
# with loco-assets.img (the original Locomotion assets) as a 4th IDE disk.
#
# Why a separate machine rather than the shared `one`: the earlier launcher
# (run-aros-loco.sh) hardcoded machine `one` - the same qcow2, the same
# /tmp/aros-one-*.sock and the same owner file. Starting it while another
# session had `one` up would have opened that session's disk read-write from a
# second QEMU, which corrupts it. This follows the `onetwo` convention instead:
# a copy of the disk, its own sockets, its own shared drive.
#
# Usage:  AROS_VM_OWNER=<session-id> ./run-loco-vm.sh
#
# Three disks besides the system one, and the split is deliberate:
#   loco-home.img    LOCOHOME: the game install, its config and its saved games.
#                    Written by the guest, which is why it is a real raw disk
#                    and not vvfat - a guest write to vvfat silently corrupts
#                    the host file. Also why the install is put here from the
#                    host: copying its 170 files inside the guest is slow, and
#                    a directory of that size has hung AROS before.
#   loco-assets.img  LOCODATA: the original Locomotion assets, read-only in
#                    practice. 510 MB, past vvfat's 516 MB FAT16 ceiling.
#   shared-loco      vvfat, for dropping in a freshly cross-compiled binary.
#                    A snapshot taken when QEMU starts: populate it BEFORE
#                    launching, and restart to pick up later changes.
# There is no CD-ROM: its IDE slot is where loco-home.img goes.
#
# LOCO_DISK3=<image> puts a different image in the assets slot. All four IDE
# slots are taken, so a disk experiment that must not touch the assets or the
# saved games gets its own throwaway image this way - which is how
# tests/fat32-overwrite is meant to be run. The game will not start without the
# assets, and that is fine: such a run is not about the game.

set -e
AROS_TESTBENCH=${AROS_TESTBENCH:-$HOME/Work/AROS}
cd "$AROS_TESTBENCH"

DISK=aros-loco-hd.qcow2
[ -f "$DISK" ] || { echo "no $DISK in $AROS_TESTBENCH - make it with:" >&2
                    echo "  cp aros-one-hd.qcow2 $DISK" >&2; exit 1; }
DISK3=${LOCO_DISK3:-loco-assets.img}
for img in "$DISK3" loco-home.img; do
    [ -f "$img" ] || { echo "no $img in $AROS_TESTBENCH - see docs/backlog/open-questions.md, 'Returning after a break'" >&2; exit 1; }
done

# Refuse to run twice: two QEMUs on one qcow2 is the failure this script exists
# to avoid, and it would be a copy of it.
if pgrep -f "$DISK" >/dev/null 2>&1; then
    echo "machine loco is already running (a QEMU holds $DISK)" >&2
    echo "check with: $AROS_TESTBENCH/vm.sh status" >&2
    exit 1
fi

mkdir -p shared-loco

GFX=${GFX:-vmware}
if [ "$GFX" = "vmware" ]; then
  GFX_ARGS=(-device vmware-svga,vgamem_mb=32)
else
  GFX_ARGS=(-vga std -global VGA.vgamem_mb=64)
fi

# AUDIO=wav writes what the guest plays to a file instead of the speakers, so
# "is there any sound at all" becomes a question you can answer by looking. The
# file is only flushed when QEMU exits. Needed for the OpenAL audio item.
AUDIO_WAV=${AUDIO_WAV:-/tmp/aros-loco-audio.wav}
if [ "${AUDIO:-}" = "wav" ]; then
  AUDIO_ARGS=(-audiodev "wav,id=snd0,path=$AUDIO_WAV" -device AC97,audiodev=snd0)
  echo "audio -> $AUDIO_WAV (written when QEMU exits)"
else
  AUDIO_ARGS=(-audiodev coreaudio,id=snd0 -device AC97,audiodev=snd0)
fi

{
  echo "machine  loco"
  echo "started  $(date '+%Y-%m-%d %H:%M:%S')"
  echo "by       ${AROS_VM_OWNER:-$(whoami)@$(hostname -s)} (run-loco-vm.sh)"
  echo "gfx      ${GFX:-vmware}"
  echo "disk     $DISK"
  echo "shared   shared-loco"
  echo "disk3    $DISK3"
} > /tmp/aros-vm-loco.info

exec qemu-system-x86_64 \
  -machine pc,accel=tcg \
  -cpu qemu64 \
  -smp 2 \
  -m 2048 \
  -hda "$DISK" \
  -drive file=fat:rw:shared-loco,format=raw,if=ide,index=1 \
  -drive file=loco-home.img,format=raw,if=ide,index=2 \
  -drive file="$DISK3",format=raw,if=ide,index=3 \
  "${GFX_ARGS[@]}" \
  "${AUDIO_ARGS[@]}" \
  -netdev user,id=net0 -device e1000,netdev=net0 \
  -usb -device usb-tablet \
  -display cocoa \
  -rtc base=localtime \
  -serial file:/tmp/aros-loco-serial.log \
  -monitor unix:/tmp/aros-loco-monitor.sock,server,nowait \
  -qmp unix:/tmp/aros-loco-qmp.sock,server,nowait \
  -boot c
