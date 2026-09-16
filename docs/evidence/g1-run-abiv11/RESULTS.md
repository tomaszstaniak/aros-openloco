# OpenLoco with the supplied g1.DAT - ABIv11

Machine: AROS One x86_64 ABIv11, QEMU TCG, `one`. Unstripped binary, run from
`RAM:loco`, assets in `RAM:Locomotion`.

---

## Run 1 (2026-09-13, session `codex-root-20260913T2031`)

Startup got past the missing-g1 validation but ended with:

```
[ERR] Warning: file /home/.config/OpenLoco/objects could not be found
[ERR] Unable to create software renderer: No system window
```

The log also showed a suspicious path, `RAM Disk:loco/RAM:Locomotion`.
Evidence: `01-renderer-failure.png`, `02-run-log.png`.

---

## Run 2 (2026-09-13, evening) - five blockers removed

### What was fixed and why

**1. "No system window" - this was not about acceleration.**
The AROS backend in SDL3 only opens the Intuition window in
`AROS_ShowWindow_Internal()`, so a window created with `SDL_WINDOW_HIDDEN` has
no `data->win` yet. OpenLoco creates its window **hidden**
(`SDL_PROP_WINDOW_CREATE_HIDDEN_BOOLEAN`, `Ui.cpp:224`), builds the renderer,
and only then calls `SDL_ShowWindow()` (`Ui.cpp:286`). On AROS that order was
impossible.
Our `tests/sdl3-smoke/` did not catch it because it creates a **visible**
window - hence the earlier "SDL3 works" alongside the game failing.
Patch: `patches/dependencies/sdl3-3.4.12-aros-hidden-window-framebuffer.diff`
(the system window is opened on demand). Worth sending to contrib.

**2. `/home/.config/OpenLoco`.** `getpwuid()` returns `/home` on AROS and XDG
does not exist. Patch 12.

**3. `RAM Disk:loco/RAM:Locomotion`.** `fs::canonical()` only treats a path with
a leading `/` as absolute, so the AmigaDOS path was taken as relative and
appended to the working directory. Paths with a volume or assign before the
first slash now pass through untouched. Patch 12.

**4. `cannot create directories`.** Twice: first a literal
`PROGDIR:OpenLoco/logs` (to `std::filesystem` `':'` is an ordinary character,
not a volume separator), then a collision between the `OpenLoco` directory and
the executable of the same name ("Not a directory"). The user directory is now
the program's own drawer. Patches 13 and 14.

**5. "Another instance of OpenLoco is already running".** `fcntl(F_SETLK)` does
not exist on AROS. The guard is disabled **deliberately**: an AmigaDOS
equivalent would have to be removed on exit, and anything left behind by a crash
would block every later run. The consequence is recorded in the patch: two
instances can overwrite each other's saves. Patch 15.

### What was achieved

**The game window is created and the OpenLoco engine draws into it.**
`05-game-window-created.png` - a native Intuition window titled "OpenLoco".
`03-first-engine-frame.png` - the game drawing its own content through its
software renderer into an SDL3 texture. That is the first frame rendered by the
game's engine on AROS.

**Neither menu nor map was reached.**

### Blocker: missing original game assets

`~/Work/AROS/shared/Locomotion/` held **only `g1.DAT`** (2 526 360 B) and
`README.txt`. After creating empty `Scenarios/` and `ObjData/` (which cleared
the `directory iterator cannot open directory` exception) startup stops at:

```
Exception 'Failed to open 'RAM:Locomotion/Data/title.dat' for writing',
thrown at 'FileStream' - src/Core/src/FileStream.cpp:84
```

Evidence: `04-missing-title-dat.png`.

A note on that message: "for writing" is misleading and comes from upstream -
`FileStream.cpp:83` throws the same text for any failed open, including a read
(there is a `// TODO: Make this work like fstream` right there). The file simply
does not exist.

**What is missing, straight from `Environment.cpp:310-400`:**

| Asset | Used for |
|---|---|
| `Data/title.dat` | the title-screen sequence - **the current blocker** |
| `ObjData/` (contents) | the game's base objects; an empty directory is not enough |
| `Scenarios/` (contents) | scenarios, for loading a map |
| `Data/CSS1.DAT`…`CSS5.DAT` | sound |
| `Data/20s1-6`, `40s1-3`, `50s1-3`, `60s1-3`, `70s1-3`, `80s1-4`, `90s1-2`.DAT | music |
| `Data/KANJI.DAT`, `Chrysanthemum.DAT`, `Eugenia.DAT`, `Rag1-3.DAT` | fonts and music |
| `Data/TUT800_1-3.DAT`, `TUT1024_1-3.DAT` | the tutorial |

In short: **the whole installed game directory is needed**, not individual
files. Further runs will reveal the next missing item one at a time, because the
game stops at the first.

### A side observation worth keeping

When OpenLoco ends with an exception, its window stays on screen and **blocks
Intuition input** - clicks in the Shell stop working and the screen does not
redraw. The only way out was stopping the machine. In later attempts run the
game with `run >RAM:log OpenLoco` so the Shell stays usable, and expect a
restart after a crash.

### How to repeat this

The install path can be set up front instead of typed by hand -
`RAM:loco/openloco.yml`:

```yaml
loco_install_path: RAM:Locomotion
```

The rest of the procedure: `first-run-abiv11/RESULTS.md`.
