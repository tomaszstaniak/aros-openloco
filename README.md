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
```

### Running it on AROS One

```sh
cp build/abiv11/openloco/OpenLoco ~/Work/AROS/shared/loco/    # before starting QEMU
cp -R build/abiv11/openloco/data  ~/Work/AROS/shared/loco/
GFX=std scripts/run-loco-vm.sh       # machine `loco`: own disk copy, assets and saves disks
```

In the guest:

```
makedir RAM:loco
copy "Qemu Vvfat:loco" RAM:loco ALL QUIET
cd RAM:loco
run >RAM:run.log OpenLoco
```

`RAM:loco/openloco.yml` must contain `loco_install_path: Locodata:Locomotion`
(copied from `shared/loco/`). Details and evidence:
`docs/evidence/menu-abiv11/RESULTS.md`.

The ABI names (`abiv11`, `mainline-v1`) and the toolchain and SDK paths live in
one place: `scripts/env.sh`. They can be overridden through environment
variables.

## State

The game runs on ABIv11: menu, title screen and a loaded scenario -
`docs/evidence/menu-abiv11/RESULTS.md`. Assessment, numbers and remaining
blockers: `docs/AROS-ASSESSMENT.md`. Open items: `docs/backlog/`.
