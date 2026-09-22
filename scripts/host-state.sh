#!/bin/sh
# Host state next to a measurement: load, memory pressure, swap, other QEMUs.
echo "=== $1 $(date '+%Y-%m-%d %H:%M:%S') ==="
uptime | sed 's/^/load:   /'
vm_stat | awk '/Pages free|Pages active|Pageins|Pageouts|Swapins|Swapouts|compressed/{printf "mem:    %s\n", $0}'
sysctl -n vm.swapusage | sed 's/^/swap:   /'
memory_pressure 2>/dev/null | tail -1 | sed 's/^/press:  /'
ps -Ao pid,%cpu,args | grep "[q]emu-system" | sed 's/\(-hda [^ ]*\).*/\1/' | sed 's/^/qemu:   /'
