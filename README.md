# aros-openloco

A port of OpenLoco (a reimplementation of Chris Sawyer's Locomotion) to native
AROS x86_64. **Primary target: ABIv11** (AROS One). Second target: mainline v1.

This repository holds only our own material - documentation, scripts, patches
and tests. The game's code is not versioned here: a script fetches it at a
pinned commit.

## Layout

```
docs/          documentation, evidence and backlog
  AROS-ASSESSMENT.md   feasibility assessment for the port
  evidence/            logs, results and screenshots the documentation cites
  backlog/             open questions and next tasks
  plans/               plans for longer changes
scripts/       bootstrap, dependencies, probes, builds
toolchains/    CMake toolchain files, one per ABI
patches/
  openloco/            our changes to the game's code (applied onto work/)
  dependencies/        dependency patches, each justified in its header
tests/         our own test code (not the game's)
upstream/      clean checkout of the pinned commit - read-only, outside Git
work/          working copy with the patches applied - outside Git
build/<abi>/   build output - outside Git
deps/<abi>/    external dependencies - outside Git
```

`upstream/` is the reference and we never edit it - that way it is always clear
what is ours and what is the game's. Changes to the game's code are made in
`work/` and made permanent as patches:

```sh
scripts/save-patch.sh <name> "why this patch exists"
```

`work/` has its own private Git repository whose first commit is upstream plus
all patches. That is not the port's history - it is the mechanism that lets
`git -C work/OpenLoco status` answer exactly one question: what have I changed
and not yet saved as a patch. **`bootstrap.sh --reset` refuses to delete `work/`
if it holds unsaved changes**; only `--force` throws them away.

We commit only to this repository. Sending anything to OpenLoco upstream would
be a separate, deliberate step (a pull request adding AROS support) - a local
commit never sends anything there.

## From scratch - the full path to a running game

After a longer break, **start with `docs/backlog/open-questions.md`, section
"Returning after a break"** - it lists the things outside this repository
without which the steps below will not work.

```sh
# 0. preconditions (outside the repo) - see the backlog, "Returning after a break"
hdiutil attach -readonly ~/Work/AROS/aros-build.sparseimage   # collect-aros needs this

# 1. sources and dependencies
scripts/bootstrap.sh                 # upstream/ at the pinned commit + work/ with patches
scripts/fetch-deps.sh abiv11         # SDL3 (contrib + our patches), fmt, sfl, yaml

# 2. libraries and CMake packages the SDK does not have
scripts/build-sdl3.sh abiv11         # libSDL3_static.a + SDL3Config.cmake -> deps/abiv11
scripts/make-cmake-packages.sh abiv11  # OpenALConfig.cmake -> deps/abiv11

# 3. the game
scripts/build-openloco.sh abiv11     # -> build/abiv11/openloco/OpenLoco (~14 MB, do NOT strip)

# optional: platform tests
scripts/compile-probe.py             # compile probe, both ABIs -> docs/evidence/
scripts/build-smoke.sh abiv11        # SDL3 + std::thread
scripts/build-png-smoke.sh abiv11    # PNG/zlib without the stubs
scripts/build-fat32-overwrite.sh abiv11   # POSIX O_TRUNC on a FAT32 volume
```

### Running it on AROS One

The install lives on `loco-home.img` and is put there **from the host**, with
QEMU stopped: copying its 170 files inside the guest is slow, and a directory
of that size has hung AROS before.

```sh
cd ~/Work/AROS
hdiutil attach loco-home.img -nobrowse
cp <port>/build/abiv11/openloco/OpenLoco /Volumes/LOCOHOME/loco/
dot_clean -m /Volumes/LOCOHOME                 # macOS ._* files load as objects
hdiutil detach /Volumes/LOCOHOME

AROS_VM_OWNER=<your-session> GFX=std ./vm.sh start loco
```

In the guest, one Shell (`meta_r-w` from Wanderer):

```
cd Locohome:loco
OpenLoco >run.log
```

`Locohome:loco/openloco.yml` must contain
`loco_install_path: Locodata:Locomotion`. Note that the AROS Shell does not
understand `2>&1` - it returns to the prompt at once - so `[ERR]` lines stay on
screen while the log keeps only stdout.

**Saved games on that FAT32 volume are not safe yet**: on AROS a POSIX rewrite
of an existing file silently loses the data, and the volume twice acquired a
zeroed `FAT[0]`. Keep a host-side copy. See
`docs/evidence/fat32-corruption/RESULTS.md` and backlog item 18.

Details and evidence: `docs/evidence/gameplay-abiv11/RESULTS.md`, and
`docs/evidence/menu-abiv11/RESULTS.md` for how the assets disk was built.

The ABI names (`abiv11`, `mainline-v1`) and the toolchain and SDK paths live in
one place: `scripts/env.sh`. They can be overridden through environment
variables.

## State

The game is playable on ABIv11: menu, scenario, construction, a running clock,
and a saved game that survives closing and restarting the program -
`docs/evidence/gameplay-abiv11/RESULTS.md`. No vehicle has been run yet, and
storage on FAT32 is unsafe (item 18). Assessment, numbers and remaining
blockers: `docs/AROS-ASSESSMENT.md`. Open items: `docs/backlog/`.
