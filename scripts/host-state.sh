#!/bin/sh
# One line describing how loaded the host is, for the record of a test run.
#
#   scripts/host-state.sh [label]
#
# Backlog item 21 is a hang that was seen repeatedly and then not at all, and
# the one thing clearly different between the two periods was the host - yet
# nobody had written its state down for the failing runs. Free memory alone
# does not describe memory pressure on macOS, so this records the kernel's
# pressure level, swap use and the free percentage, the load averages, and
# which QEMU machines were running - their names, since the testbench is shared
# and other sessions' guests compete for the same CPU.
#
# Appends to $AROS_TESTBENCH/loco-variants/host-state.log and prints the line.
TB=${AROS_TESTBENCH:-$HOME/Work/AROS}
LOG=$TB/loco-variants/host-state.log
mkdir -p "$(dirname "$LOG")"

# 1 normal, 2 warning, 4 critical
lvl=$(sysctl -n kern.memorystatus_vm_pressure_level 2>/dev/null)
case "$lvl" in 1) lvl=normal;; 2) lvl=warn;; 4) lvl=critical;; esac
freepct=$(memory_pressure 2>/dev/null | awk -F': ' '/free percentage/{print $2}')
swap=$(sysctl -n vm.swapusage 2>/dev/null | awk '{print $6}')
load=$(sysctl -n vm.loadavg 2>/dev/null | tr -d '{}' | awk '{print $1"/"$2"/"$3}')
qemus=$("$TB/vm.sh" status 2>/dev/null | awk -F: '/: running/{printf "%s ", $1}')

line="$(date '+%Y-%m-%d %H:%M:%S') ${1:-} pressure=$lvl free=$freepct swap_used=$swap load=$load qemu=[${qemus% }]"
echo "$line" >> "$LOG"
echo "$line"
