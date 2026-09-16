# First run of OpenLoco on AROS - result

2026-09-13. Machine: **AROS One 64-bit (ABIv11)**, QEMU (TCG), `vm.sh one`,
started by this session. Binary: `build/abiv11/openloco/OpenLoco`, 14 217 528 B,
**not stripped** (see backlog §11 - a full strip breaks relocations).

## Result: the program starts and walks the whole asset-detection path

The original Chris Sawyer's Locomotion assets are not on this machine, so the
test ends where it must - at the missing `Data/g1.DAT`. **That is not a failure
of the port but missing input data**, and the path leading up to it is exactly
what was meant to be checked.

Game log (`RAM:ver.log`, screenshot 03):

```
[INF] OpenLoco, 1138d80 (1138d80 on baseline)
[INF] AROS (x86-64)
[INF] Searching for Locomotion install path...
Type your Locomotion path:
```

Console:

```
[ERR] Unable to automatically find the Locomotion game folder.
Please provide the location manually.
RAM:loco
[ERR] The selected folder does not contain Data/g1.DAT
```

### What this confirms

| | evidence |
|---|---|
| The program loads and starts | the prompt returns, no "Illegal address access" |
| 19 library bases open | `SysBase`, `DOSBase`, `IntuitionBase`, `GfxBase`, `CyberGfxBase`, `GLBase`, `OpenALBase`, `MUIMasterBase`, `GadToolsBase`, `IconBase`, `IFFParseBase`, `KeymapBase`, `LowLevelBase`, `TimerBase`, `WorkbenchBase`, `CxBase`, `CrtBase`, `StdlibBase`, `MBase` - the program reached its own code, so autoinit succeeded |
| C++ static constructors | logging and `Version::getVersionInfo()` work before anything else |
| **Platform identification** | `[INF] AROS (x86-64)` - patch `01-aros-platform-identification` |
| Logging | both to the console and through redirection to a file |
| **An SDL3 window on AROS** | two different messages as native Intuition windows (screenshots 01 and 02) - the `SDL_arosmessagebox` backend |
| Reading stdin | `std::getline` accepted the typed path |
| `std::filesystem` | correctly determined that `Data/g1.DAT` is absent in the given directory |
| Clean exit | back to the Shell without hanging and without leftovers on screen |

### Screenshots

- `01-first-run-messagebox.png` - the first window: "Unable to automatically
  detect the Locomotion game folder."
- `02-game-path-validation.png` - the second window after entering a path: "The
  selected folder does not contain Data/g1.DAT…"
- `03-log-and-clean-exit.png` - the contents of `RAM:ver.log` with
  `[INF] AROS (x86-64)`, and the return to the prompt.

## What this test did NOT show

- **Menu, map, gameplay.** Without `Data/g1.DAT` the game never reaches video
  initialisation - no game window was created, not a single frame was drawn, and
  audio was never touched. Steps 2-4 of the plan (menu, scenario, save/load) are
  **untouched**.
- **The renderer.** These were SDL3 message boxes, not `SDL_CreateRenderer` or
  the game's screen texture. The test says nothing about performance.
- **Audio.** `OpenALBase` is among the binary's requirements, but nothing
  played.
- **Networking.** Untouched.

## How to approach steps 2-4 (menu, map, save)

Two things have to happen **before** the machine starts, otherwise the attempt
begins by diagnosing the wrong symptoms:

1. **Share the whole installed game directory, not just `Data/`.**
   `Data/g1.DAT` only clears the first gate; scenarios and objects reach
   further, and missing files would then look like defects in the port.
   Location: `~/Work/AROS/shared/Locomotion/` (a separate directory - see the
   warning below).
2. **Copy them before QEMU starts.** The vvfat drive is **a snapshot taken when
   the machine starts**: files added to `shared/` while AROS is running are
   invisible to the guest, and waiting does not help - only a restart does
   (`../../../../docs/platform/testbench.md`). "The machine is still running"
   does **not** mean the test can be picked up immediately.

**Do not put the Locomotion assets next to OpenLoco's `data/` in one
directory.** The host is case-insensitive: the game's `Data/` and OpenLoco's
`data/` would merge into a single directory on macOS. That is the same property
that made `<graphics/gfx.h>` resolve to `OpenLoco/Graphics/Gfx.h` earlier. Hence
a separate `shared/Locomotion/` alongside `shared/loco/`.

## How to repeat this

**Do not copy `data/` over a CD** - 168 files in one directory hang `copy`
forever at 100% CPU (see `../../../../docs/platform/porting-notes.md`). Use the
vvfat drive.

### The variant we tested: everything in RAM:

Both the game and the assets end up in RAM:, with vvfat used only to move them
into the guest. The reason is single and concrete: **a write from the guest onto
vvfat silently corrupts files on the host side**, and we do not know in advance
whether OpenLoco writes anything next to the assets. RAM: does not have that
problem and is faster. There is room - RAM: showed about 1 GB free.

```sh
# ON THE HOST, before starting QEMU:
cp -R build/abiv11/openloco/OpenLoco build/abiv11/openloco/data ~/Work/AROS/shared/loco/
cp -R "<Locomotion installation>"/* ~/Work/AROS/shared/Locomotion/
~/Work/AROS/vm.sh start one          # the FAT is built when QEMU starts
```

```
; IN THE GUEST:
makedir RAM:loco
copy "Qemu Vvfat:loco" RAM:loco ALL QUIET
makedir RAM:Locomotion
copy "Qemu Vvfat:Locomotion" RAM:Locomotion ALL QUIET
cd RAM:loco
OpenLoco >RAM:run.log
; when it asks for the path, enter:
RAM:Locomotion
```

The program runs from `RAM:loco` because `PROGDIR:` has to be writable.

### The alternative: assets stay on vvfat

Then **only** OpenLoco goes into RAM: and the game is given
`Qemu Vvfat:Locomotion`. It saves copying tens of megabytes, but it is only good
as long as the game writes nothing in that directory - which we have not
checked. **Do not mix the variants:** the path given to the game must point at
the volume the assets actually landed on.
