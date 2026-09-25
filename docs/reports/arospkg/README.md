# OpenLoco in the arospkg index - draft and apkg test

`openloco.x86_64.toml` is a **draft** overlay manifest for the arospkg index
(`status = "draft"`). It points at the published GitHub **prerelease**
v0.1.0-rc1 asset, unchanged. Approval is the index maintainer's decision.

## apkg test, 2026-09-25

Pool slot `v11-1`, AROS One 1.3 x86_64 (ABIv11), QEMU. Client: the public
`apkg` 0.1 from arospkg's `dist/` (SHA-256 `ca010440…66f1`). A test-only
index built by `tools/mkindex.py` from a copy of the draft with `status`
switched to `approved` (`evidence-2026-09-25/test-index.json`, never
published); mkindex checked `subdir = "OpenLoco"` inside the real archive.
Separate test root `SYS:PkgLoco` (`--root`, `--index`), deleted afterwards.
Locomotion files supplied separately (`assign Locodata: AROS:`).

| step | result |
|---|---|
| install | fetched the release URL over HTTPS (followed GitHub's redirect), `verified and cached`, `installed openloco`, rc 0. `requires_system` openal.library: *satisfied* (version 45) |
| start | fresh Shell, 40 KB stack, `cd SYS:PkgLoco/openloco`, `execute Run-OpenLoco`: title menu, version `5c0eaac on openloco-next+21` |
| play | scenario map; saved as `apkg-test-01` (1,504,669 B); exit from the game menu. The game rewrote `openloco.yml` (297 → 4,099 B) |
| `apkg remove` | `removed openloco`, rc 0. Report in `db/doctor/`: 234 removed, **1 kept modified: `openloco.yml`**. Left in the drawer: that `openloco.yml`, `save/apkg-test-01.SV5`, `logs/`, and the game-created `scores.dat`, `plugin.dat`. Program and `data/` gone |
| install again | **refused**, rc 10: `a directory of that name is already there … Usually left by an earlier removal that kept files you had changed. Nothing was changed. Move it away and install again.` |
| move away, install | `rename … openloco-kept`, install from cache, rc 0 |
| restore by hand | copied `save/` and `openloco.yml` back from `openloco-kept` |
| reload | `Run-OpenLoco`, Load Game → `apkg-test-01`: the saved game loaded (same map, company, 19 Jan 1930) |

So: **remove keeps the save and the user-changed `openloco.yml`**, and nothing
is lost. **Reinstalling does not reuse them**: `apkg` refuses to install over
the kept drawer, and the user has to move it, install, and copy their files
back. That is safe but manual; it is `apkg`'s documented behaviour, not
something the package can change.

Other observations:

- the empty `objects/` drawer in the archive is **not created** by `apkg`
  (it is by `lha x`); the game then logs
  `Warning: file …/objects could not be found`. Harmless; worth a line to the
  arospkg maintainer (empty directories in an archive);
- the removal report goes to `db/doctor/<id>-*.json`; nothing about the kept
  files is printed on the console;
- the other `[ERR]` lines in the logs are the upstream ones known from every
  run (bogie sprites, `scores.dat` before first write, `save/autosave` before
  the first autosave).

## Requirements

From the rc1 binary (`tools/deps.py` and `strings`), filtered per the manifest
guide 4.3: `openal.library` is the one listed - it is opened at start-up, so
without it the program cannot start. `bsdsocket.library` is opened only when
networking is used (patch 25): not a requirement. `crt.library`,
`m.library`, `stdlib.library` are referenced and present on AROS One 1.3
(5.2, 1.0, 3.0). First left out; the index maintainer's measured lists show
all three on AROS One and none on mainline, so they are listed (2026-09-25).

## For a later release (not rc1)

- a drawer icon `OpenLoco.info` beside `OpenLoco/` (`icon` field). It improves
  the Workbench view only - it does **not** start the game with a 1 MB stack.
  A Workbench start needs a project/tool icon for the program or the launcher
  with its stack set to 1,048,576, tested separately;
- an embedded `.arospkg/manifest.toml`, with `openloco.yml` as
  `[[files]] kind = "config"` - the game rewrites it on first exit;
- consider shipping `objects/` with a placeholder file, or creating it in
  `Run-OpenLoco`, so package-manager installs do not warn.

## Agreed with the index maintainer (2026-09-25)

- prerelease: the version string `0.1.0-rc1` says it; the summary describes
  the program only;
- requirements: all four libraries;
- own Locomotion files and `Run-OpenLoco`: in the archive's README for now;
  an optional `notes` field is planned in arospkg after its v0.2 freeze;
- the missing `objects/`: an arospkg bug - its LHA reader skipped empty
  `-lhd-` members. Fixed in arospkg (host test added), shipping with its v0.2;
  nothing to change in the package; the kept-files console message is planned for
  arospkg v0.2;
- approval after arospkg's v0.2 freeze.

## apkg v0.2 test, 2026-09-25 evening

Same slot and archive, final `apkg` 0.2 (SHA-256 `ba9a94d9…58b9`, the binary
arospkg's v0.2 is frozen on), fresh test index from the corrected draft,
test roots `SYS:PkgLoco2`/`3`, deleted afterwards. Evidence:
`evidence-2026-09-25-v02/`.

| step | result |
|---|---|
| install from a Shell with the **default 40 KB stack** | **apkg crashed**: `Stack extends out of range` (screenshot `apkg02-crash-default-stack.png`); its lock stayed held until reboot. An apkg issue, reported to arospkg |
| install with `stack 262144`, fresh boot | rc 0, `installed openloco`; **empty `objects/` now created** |
| `Run-OpenLoco` | menu, scenario map, saved `apkg02-test` (1,484,437 B), exit |
| `apkg remove` | rc 0; console: `note: 1 file(s) changed locally were kept in SYS:PkgLoco3/openloco: openloco.yml` then `removed openloco`; save kept |

The OpenLoco entry passed; the default-stack crash is apkg's.
