#!/bin/zsh
# Launch AROS One 64-bit (ABIv11) in QEMU on Apple Silicon (TCG emulation).
#
# Usage:
#   ./run-aros.sh            boot from hard disk (after install)
#   ./run-aros.sh install    boot from ISO to install onto the qcow2 disk
#   ./run-aros.sh live       boot the ISO live, disk attached
#
# The ./shared directory is exposed as a FAT drive inside AROS (read-only
# snapshot semantics on the guest side are fine for dropping in freshly
# cross-compiled binaries; reboot or re-read the drive to pick up changes).

set -e
cd "$(dirname "$0")"

ISO=AROS-One-64bit-v1.3.iso
DISK=aros-one-hd.qcow2
mkdir -p shared

BOOT_ARGS=(-boot c)
case "$1" in
  install|live) BOOT_ARGS=(-cdrom "$ISO" -boot d) ;;
esac

# Graphics device. "vmware" uses AROS's vmwaresvga.hidd: hardware mouse
# pointer (no redraw trails) and resolutions selectable from Prefs/ScreenMode
# instead of being fixed by the GRUB vesa= argument.
# Fall back with:  GFX=std ./run-aros.sh
GFX=${GFX:-vmware}
if [ "$GFX" = "vmware" ]; then
  GFX_ARGS=(-device vmware-svga,vgamem_mb=32)
else
  GFX_ARGS=(-vga std -global VGA.vgamem_mb=64)
fi

# AUDIO=wav writes what the guest plays to a file instead of the speakers, so
# "is there any sound at all" becomes a question you can answer by looking. The
# file is only flushed when QEMU exits.
AUDIO_WAV=${AUDIO_WAV:-/tmp/aros-audio.wav}
if [ "${AUDIO:-}" = "wav" ]; then
  AUDIO_ARGS=(-audiodev "wav,id=snd0,path=$AUDIO_WAV" -device AC97,audiodev=snd0)
  echo "audio -> $AUDIO_WAV (written when QEMU exits)"
else
  AUDIO_ARGS=(-audiodev coreaudio,id=snd0 -device AC97,audiodev=snd0)
fi

# Record who started this, so ./vm.sh status can say. Several agents share
# these machines and the sockets alone do not identify the owner.
{
  echo "machine  one"
  echo "started  $(date '+%Y-%m-%d %H:%M:%S')"
  echo "by       ${AROS_VM_OWNER:-$(whoami)@$(hostname -s)} (run-aros.sh)"
  echo "gfx      ${GFX:-vmware}"
} > /tmp/aros-vm-one.info

exec qemu-system-x86_64 \
  -machine pc,accel=tcg \
  -cpu qemu64 \
  -smp 2 \
  -m 2048 \
  -hda "$DISK" \
  -drive file=fat:rw:shared,format=raw,if=ide,index=1 \
  -drive if=ide,index=2,media=cdrom \
  -drive file=loco-assets.img,format=raw,if=ide,index=3 \
  "${GFX_ARGS[@]}" \
  "${AUDIO_ARGS[@]}" \
  -netdev user,id=net0 -device e1000,netdev=net0 \
  -usb -device usb-tablet \
  -display cocoa \
  -rtc base=localtime \
  -serial file:/tmp/aros-one-serial.log \
  -monitor unix:/tmp/aros-one-monitor.sock,server,nowait \
  -qmp unix:/tmp/aros-one-qmp.sock,server,nowait \
  "${BOOT_ARGS[@]}"
