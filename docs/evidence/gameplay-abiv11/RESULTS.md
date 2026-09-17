# OpenLoco on AROS: a full game cycle on a persistent disk - ABIv11

2026-09-17, 19:47-20:35. Machine: **AROS One 64-bit (ABIv11)**, QEMU TCG,
machine **`loco`** (new, see below), `GFX=std`, started by this session.
Unstripped binary, 15 game patches plus the dependency patches. SHA-256 of the
binary matches `build/abiv11/openloco/OpenLoco` exactly - nothing stale was
deployed.

Game install, configuration and saved games: **`Locohome:loco`**, a 512 MB
FAT32 disk image (`loco-home.img`) attached as a real IDE disk, not vvfat.
Original assets: `Locodata:Locomotion` (`loco-assets.img`), unchanged.

## Result: the game is playable and a saved game survives a restart

| step | evidence | outcome |
|---|---|---|
| start, the asset noise is gone | `01-title-menu.png` | **4 `[ERR]` lines instead of a flood** - the `._*` cleanup worked |
| load a scenario ("Sandbox Settler", Beginner) | `02-scenario-loaded.png` | map, company window, $9,918, clock at 17th February 1900 |
| the simulation actually runs | dates across screenshots | 17 Feb -> 26 Feb -> 13 Mar -> ... -> 14 Oct 1900, running costs draw the balance down |
| build a route | `04-railway-built.png` | 6 tiles of railway, $9,568 -> $9,376 |
| build a station | `05-station-built.png` | station **"Sagginghead"** on the line |
| save to the persistent disk | `06-save-dialog.png` | folder `Locohome:loco/save/`, 952,272 B written |
| the file is really on the disk | `07-save-file-on-disk.png` | listed by the game, and by `list` from the AROS Shell |
| **exit the program, restart, load** | `08-save-reloaded.png` | **the state comes back**: the same map, no track (the save predates it), 10th June 1900, **$9,590 - the same figure noted when that save was made** |
| autosave | 9 files, every ~72 s | 919-958 KB each, all written without trouble |

A copy of the reloaded save is kept in `saves/` next to this file - the
artefact the claim rests on, and the only copy outside the disk image.

## The freeze: one occurrence, and it did not come back

**What happened.** Saving over an existing file: Save Game -> OK -> "Replace
existing file?" -> Replace. The prompt closed, the save dialog stayed, and the
game stopped:

- two screendumps **80 s apart were byte-identical** (sha1 equal) - the window
  was not redrawing at all, so this was not the simulation merely pausing;
- the QEMU process sat at **101% CPU** - the guest was spinning in a loop, not
  waiting on I/O;
- the target file was **not** updated: `Sandbox Settler.SV5` kept its earlier
  size and timestamp;
- the last autosave before it is 20:14:00 and the Replace click was at ~20:14.

`fsck_msdos -n` on the image afterwards:

```
Warning: FAT[0] is incorrect (is 0x0; should be 0xFFF8)
Warning: /LOCO/OPENLOCO.YML starts with free cluster
Warning: /LOCO/OPENLOCO.YML: Cluster chain starting at 3778 ends with cluster marked free
```

`openloco.yml` is the file `Config::write()` rewrites on every save
(`PromptBrowseWindow.cpp:990`).

**The retry did not reproduce it.** After `fsck_msdos -y` repaired the volume
and the save was reloaded, the same path was walked again - this time with every
click checked against a fresh screendump, and with the "Replace existing file?"
prompt captured before clicking it (`09-replace-prompt.png`). It **saved
normally** (`10-overwrite-succeeded-on-retry.png`): the dialog closed, the clock went on running, CPU stayed at 67-75%,
and consecutive screendumps differed.

**So the first reading was wrong.** "Overwriting a save hangs the game" does not
hold. What the evidence supports instead:

1. the volume was **already damaged** when the freeze happened - a cluster
   chain running into a free cluster and a zeroed `FAT[0]`;
2. a write that walks such a chain is exactly the shape that loops forever,
   which fits the 101% CPU and the dead window;
3. on a repaired volume the same write succeeds.

**What is therefore still unknown, and it is the important part: what damaged
the volume.** Candidates, none tested: an earlier `Config::write()`; writing
from AROS to FAT32 in general; or the kill of QEMU - but that came *after* the
freeze, so it cannot explain the freeze itself, only possibly some of the
damage found later.

The AROS FAT handler is not simply unable to overwrite: from the Shell, `copy`
over an existing 307,200 B file with a 6 B one succeeded at 6.1% CPU, shrinking
it. `copy` uses `MODE_NEWFILE` while a C++ `std::ofstream` goes through posixc
with `O_TRUNC` - a difference worth isolating, which is what
`tests/fat32-overwrite/` does in plain C. **It has not been run.**

Until this is understood, **do not treat saved games on a FAT32 volume as
safe**, and keep a host-side copy: the ones this run produced are in `saves/`
next to this file.

## Two further defects found, both patched, neither rebuilt yet

**1. `fs::permissions()` fails on FAT32 - cosmetic, but loud.** At every start
the game showed two modal error boxes:

```
[ERR] Unable to create directory: filesystem error: cannot set permissions:
No such file or directory [Locohome:loco/save/]
                          [Locohome:loco/landscape/]
```

`autoCreateDirectory()` (`Environment.cpp:200`) calls `create_directories()`
and then `fs::permissions()`. The directories **are** created - `list` shows
`save`, `save/autosave`, `landscape` and `objects`, and the game uses them - so
only the chmod fails. Patch: `patches/openloco/16-aros-permissions-nonfatal.diff`.

**2. No text input in any SDL3 program on AROS.** The "Name Owner" dialog
ignored everything typed (`03-text-input-ignored.png`: the field still reads
"Unnamed", 7/31, after two attempts, one of them after clicking the field).

Cause, read out of the source rather than guessed:
`AROS_TranslateUnicode()` in `src/video/aros/SDL_arosevents.c` has its whole
body inside `#if !defined(__AROS__)` - it was written around the
MorphOS/AmigaOS4 tag `IMSGA_UCS4`. On AROS it always returns 0, so the caller
never reaches `SDL_SendKeyboardText()`. The game side is correct (it calls
`SDL_StartTextInput()` and handles `SDL_EVENT_TEXT_INPUT`), and both gates
inside SDL3 (`keyboard focus`, `text input active`) are satisfied. Patch:
`patches/dependencies/sdl3-3.4.12-aros-text-input.diff`, using
`keymap.library` the same way `AROS_MapRawKey()` in the same backend already
does. **Worth sending to contrib - it affects every SDL3 program on AROS.**

Both patches are written and saved; **neither has been compiled or run.**

## A new machine, `loco`, and why

The earlier launcher `run-aros-loco.sh` hardcoded machine **`one`**: the same
`aros-one-hd.qcow2`, the same `/tmp/aros-one-*.sock`, the same owner file.
Machine `one` was up and owned by another session (`codex-micropolis`), so
starting it would have opened that session's disk read-write from a second
QEMU. Replaced by `scripts/run-loco-vm.sh` on its own copy of the disk, its own
sockets and its own `shared-loco`, following the existing `onetwo` convention.
`loco` was added to the shared `~/Work/AROS/vm.sh` so `vm.sh status` names it
for everyone else.

## Repeating this

```sh
hdiutil attach -readonly ~/Work/AROS/aros-build.sparseimage   # trap 1
# populate shared-loco BEFORE starting QEMU - vvfat is a start-time snapshot
AROS_VM_OWNER=<your-session> GFX=std ~/Work/AROS/vm.sh start loco
```

Then in one AROS Shell (`meta_r-w` from Wanderer):

```
cd Locohome:loco
OpenLoco >run.log
```

The Shell keeps that log's **stdout only**: AROS Shell does not understand
`2>&1` (it returns to the prompt immediately), so `[ERR]` lines stay on screen.
`run1.log` came out **0 bytes** because the process was killed before the
stream flushed - do not count on the log file for a diagnosis of a freeze.

Building the game install into `loco-home.img` **from the host** is deliberate:
copying its 170 files inside the guest is slow, and a directory of that size
has hung AROS before.

## What this run does NOT show

- **No vehicle was ever run.** A route and a station exist, but "Sandbox
  Settler" in 1900 offers no depot in the station dropdown, so no train could
  be bought. Gameplay beyond construction, and the economy doing anything, are
  untested.
- **The save that was reloaded predates the route.** The state comparison
  therefore covers map, date and balance - not track, station or company
  assets. The save carrying the route was never written, because that write is
  the freeze above.
- **No performance figure.** The game responds and the clock runs under TCG;
  scenario indexing took about 4 minutes on the first start and 87 s on the
  second, and those numbers say nothing about hardware.
- **Audio.** Never requested, never heard. OpenLoco uses OpenAL, so an SDL3/AHI
  test would not answer it.
- **Mouse beyond single clicks.** Dragging, the right button, the wheel and the
  window close gadget are still untested.
- **Mainline v1.** Everything here is ABIv11.
- The `._*` cleanup is confirmed only by the drop in error lines; the objects
  themselves were not counted in the game.
