# OpenLoco for AROS (x86_64, ABIv11)

A port of [OpenLoco](https://github.com/OpenLoco/OpenLoco) - an open-source
re-implementation of Chris Sawyer's Locomotion - to native 64-bit AROS.
**Supported target: AROS One 1.3, x86_64, ABIv11.** Nothing else is supported:
not 32-bit AROS, and not mainline ABI v1 (work on it is deferred).

This is an independent port. It is not made or endorsed by the OpenLoco
project; problems found here belong to this port until shown otherwise.

This repository holds only the port's own material: patches, build scripts,
tests and documentation. The game's source is fetched from upstream at a pinned
commit and patched at build time. **No game data is included** - you need your
own copy of Locomotion.

## Download

Packages are on the [Releases](../../releases) page:
`openloco.x86_64-aros-v11.lha` and its SHA-256. Current releases are
**test releases** (prereleases); read the limitations below first.

## Requirements

- **AROS One 1.3, 64-bit (ABIv11).** Tested on emulated machines (QEMU) only.
- **Your own copy of Chris Sawyer's Locomotion** - the installed game's files
  (`Data`, `ObjData`, `Scenarios`, `g1.DAT` and the rest). They are commercial
  and are not, and cannot be, part of this port.
- About 2 GB of RAM for the machine and a writable disk: the game writes its
  config, saved games and screenshots next to itself.

## Installing and running

1. Extract the archive somewhere writable, e.g. `Work:Games/`. It creates the
   drawer `OpenLoco`.
2. Put your Locomotion files where `OpenLoco/openloco.yml` points, or edit that
   line. The default is `loco_install_path: Locodata:Locomotion`.
3. From a Shell:

       cd Work:Games/OpenLoco
       execute Run-OpenLoco

**Always start it through `Run-OpenLoco`.** The default Shell stack on
AROS One 1.3 is 40 KB; the game needs more and otherwise dies while drawing its
first screen with `Stack extends out of range`. The launcher sets
`stack 1048576`. Before starting the game it checks that it is run from inside
the drawer and that the program, `data/language` and `data/objects` are
present; if something is missing it says what, instead of failing silently.

**No sound?** AROS One may ship with its AHI units set to VOID. OpenLoco plays
through OpenAL, which uses AHI **Unit 0**. In `Prefs/AHI` select `Unit 0` with
the cycle gadget at the top, choose your card's mode (e.g.
`ac97:16 bit stereo++`), and **Save**. Details are in the package's
`README.md`.

## Known limitations

- **Saving over an existing file on FAT32.** On the FAT32 volume used for
  testing, the AROS FAT handler has lost data when an existing file was
  rewritten, and the volume was damaged twice. The port writes saves through a
  safer path, but the underlying problem is **not solved**. **Save under a new
  name** rather than over an old save, keep copies of saves you care about, and
  shut AROS down properly (`Sys:C/Shutdown`) before closing the emulator.
- **A second start in one boot froze the machine** four times early in the
  port (2026-09-17/18). It has **not been reproduced since**, but the cause
  was never found, so it is not known to be fixed. Rebooting between sessions
  avoids the situation.
- **Sound effects are unchecked.** Music has been heard playing; vehicle,
  ambient and interface sounds have not been checked by ear.
- **Performance is not characterised.** On one emulated machine the game held
  its 40 fps cap at 640x480 on a small map; nothing else has been measured in
  conditions worth quoting. The renderer is the software one.
- Wanderer crashed once on a test machine while the game sat idle; the game
  kept running and the cause is unknown.
- One unfreed signal bit is reported on exit; harmless as far as seen.

The full list, with evidence, is in `docs/backlog/open-questions.md`.

## What the package contains

The `OpenLoco` program (statically linked with SDL3, fmt, yaml-cpp, sfl,
libpng and zlib), OpenLoco's `data/` (language files and the OpenGraphics
objects), the `Run-OpenLoco` launcher, a default `openloco.yml`, a README,
the build's provenance (`BUILD-INFO.txt`, `PATCHES.txt`, `BUILT-WITH.txt`,
`DEPENDENCIES.txt`, `SHA256`) and `Licenses/`. OpenAL is the system's
`openal.library`. See [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).

The program prints its version first, e.g.
`OpenLoco, 7f8c90cf+aros (<port revision> on openloco-next+21)`: the upstream
commit, this repository's revision and the number of patches applied. Please
include that line in any report.

## Licence and credits

- This repository (scripts, tests, documentation, patch headers): MIT, see
  [LICENSE](LICENSE). The patches modify OpenLoco, SDL3, fmt and yaml-cpp and
  are offered under the licence of the project they modify.
- **OpenLoco** is © the OpenLoco developers, MIT licence; its contributors are
  listed in upstream's `CONTRIBUTORS.md`.
- SDL3 (with the AROS backend from aros-development-team/contrib), fmt,
  yaml-cpp, sfl, libpng, zlib and the OpenGraphics objects: see
  [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md); texts in `licenses/`.
- Chris Sawyer's Locomotion is not included, not free, and not part of this
  port.

## Building

Built on macOS with the AROS One ABIv11 SDK and its GCC 10.5.0 cross
toolchain. Toolchain and SDK paths are set in `scripts/env.sh` and can be
overridden through environment variables; the defaults describe the author's
machine.

The release is built from upstream `7f8c90cf` (v26.09 + 1 commit) with the
patch set `patches/openloco-next`:

```sh
export OPENLOCO_UPSTREAM_COMMIT=7f8c90cf7b1127dd1113b904336bfda3d0f4ff00 \
       OPENLOCO_UPSTREAM_DIR=$PWD/upstream-next/OpenLoco \
       OPENLOCO_WORK_DIR=$PWD/work-release/OpenLoco \
       OPENLOCO_PATCH_DIR=$PWD/patches/openloco-next \
       OPENLOCO_BUILD_ROOT=$PWD/build-release
scripts/bootstrap.sh                 # upstream checkout + patched work tree
scripts/fetch-deps.sh abiv11         # SDL3 + contrib AROS diff + our patches, fmt, sfl, yaml-cpp
scripts/build-sdl3.sh abiv11         # libSDL3_static.a + CMake package
scripts/make-cmake-packages.sh abiv11
OPENLOCO_FRESH_CONFIGURE=1 scripts/build-openloco.sh abiv11
LHA_WRITER=/path/to/jca02266-lha OPENLOCO_ARCHIVE_NAME=openloco.x86_64-aros-v11.lha \
    scripts/make-release.sh abiv11   # -> release/abiv11/
```

`build-openloco.sh` stamps the version, archives every build by its SHA-256
together with the complete source diff, and `make-release.sh` refuses builds
from a dirty tree or a reused CMake configuration. Do not fully strip the
binary: AROS needs its relocations.

A newer GCC (13.4) was evaluated and not adopted for the release; see
`docs/reports/gcc13-evaluation.md`.

## Layout

```
patches/openloco/       changes to the game, each with a header saying why
patches/openloco-next/  the patch set applied to the pinned upstream commit
patches/dependencies/   changes to SDL3, fmt and yaml-cpp
patches/diagnostics/    instrumentation used in investigations - never in a release
scripts/                bootstrap, dependencies, builds, packaging
toolchains/             CMake toolchain files, one per ABI
tests/                  the port's own reproducers and runtime tests
licenses/               licence texts of everything in the package
docs/                   assessment, backlog, reports and the evidence they cite
```

`upstream*/`, `work*/`, `build*/`, `deps/` and `release/` are generated and
not versioned. Upstream checkouts are never edited; changes are made in the
work tree and saved as patches with `scripts/save-patch.sh`.

Testing used a shared pool of QEMU machines on the author's machine; the
procedures and evidence in `docs/` refer to it.
