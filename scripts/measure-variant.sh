#!/bin/sh
# One measurement variant: boot, start the game, load the same save, leave it
# alone for the measured stretch, capture, exit, shut the guest down.
#   runvariant.sh <label>
set -e
S=$(dirname "$0"); L=$1
export AROS_QEMU_QMP=/tmp/aros-loco-qmp.sock AROS_QEMU_MONITOR=/tmp/aros-loco-monitor.sock
cd ~/Work/AROS
V() { python3 tools/vmctl.py "$@"; }

if hdiutil info | grep -q "loco-home.img"; then
    echo "loco-home.img is still attached on the host - detach it first" >&2; exit 1
fi
"$S/hoststate.sh" "$L before" > /tmp/aros-openloco/M-$L.host
(cd ~/Work/AROS-dev/aros-openloco && AROS_VM_OWNER=openloco-session nohup scripts/run-loco-vm.sh > /tmp/aros-openloco/vm-$L.log 2>&1 &)
until [ -S /tmp/aros-loco-qmp.sock ]; do sleep 2; done
sleep 3; V type "" ret                       # past GRUB
until V shot /tmp/aros-openloco/M-$L-boot.png 2>/dev/null | grep -q 1680x1050; do sleep 5; done
sleep 25
V key meta_r-w; sleep 5
V type "cd Locohome:loco" ret; sleep 2
V type "OpenLoco" ret; sleep 105               # to the title screen
V shot /tmp/aros-openloco/M-$L-title.png >/dev/null
V click 800 660; sleep 8                       # Load Game
V dclick 660 411; sleep 45                     # the same save every time
V shot /tmp/aros-openloco/M-$L-loaded.png >/dev/null
sleep 160                                      # measured stretch, untouched
V shot /tmp/aros-openloco/M-$L-measured.png >/dev/null
"$S/hoststate.sh" "$L after" >> /tmp/aros-openloco/M-$L.host
V click 543 322; sleep 5; V click 568 435; sleep 20    # Exit OpenLoco
V shot /tmp/aros-openloco/M-$L-exit.png >/dev/null
V type "Shutdown" ret; sleep 20
echo '{"execute":"qmp_capabilities"}{"execute":"quit"}' | nc -U /tmp/aros-loco-qmp.sock >/dev/null 2>&1 || true
sleep 3
echo "variant $L done"
