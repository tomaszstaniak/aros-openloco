# Release candidate 0.1.0-rc1 - the published archive, tested as shipped

2026-09-25, pool slot `v11-1` (AROS One 1.3, x86_64 ABIv11, QEMU), driven
through the pool's `vm.sh` (stage, start, stop, collect) with every boot ended
by `Sys:C/Shutdown` in the guest.

## What was tested

Exactly the file that is published:

| | |
|---|---|
| archive | `openloco.x86_64-aros-v11.lha` |
| archive SHA-256 | `59fb5f11a8fe848f249d2a3399b67d6d28f617d52c167307c3d2a596d320efe0` |
| program SHA-256 | `a84e37097be5a48d9e849438fa5a43dbdc9cc85c2b2a0e08f70c7b2f94e55732` |
| version line | `OpenLoco, 7f8c90cf+aros (5c0eaac on openloco-next+21)` |
| build | fresh CMake configure, clean work tree, GCC 10.5.0 from the AROS One SDK |
| patches | `patches/openloco-next`, 21 patches; no `patches/diagnostics` |

The game-source part of the build (`SOURCES.diff`, ignoring file timestamps)
is identical to the earlier verified candidate `24e7b3a1`; only the port
revision in the version string differs.

## Steps and results

**Boot 1** (fresh boot, archive staged on the pool's input CD):

1. The archive was checked on the host against its `.sha256`, staged,
   unpacked from the pool payload with `C:UnZip` (rc 0), then extracted with
   the system's `C:lha x` into a new drawer `AROS:olrc2` (rc 0, no errors in
   its log).
2. The extracted `OpenLoco` was copied to `Results:` and its SHA-256 compared
   on the host after collection: **identical** to the program above.
3. In a fresh Shell (`stack` reported **40960** bytes) and with
   `assign Locodata: AROS:` (where this slot keeps the Locomotion files),
   `cd AROS:olrc2/OpenLoco` and `execute Run-OpenLoco`: **title screen**
   (`01-title-5c0eaac.png`).
4. New game, scenario *Swiss Alps 1930*: **map** (`02-scenario-map.png`).
5. Save Game under a **new name** `rc1-test-02`: no error
   (`03-saved-new-name.png`); 1,499,887 bytes. An autosave followed at the
   game's interval.
6. Exit OpenLoco from the game's menu: returned to the Shell with the known
   single unfreed signal (`04-clean-exit.png`).
7. Save list and logs written to `Results:`; `Sys:C/Shutdown`; pool stop.

**Boot 2** (same slot, restarted):

8. Fresh Shell, the same drawer, `execute Run-OpenLoco`: title screen.
9. Load Game → `rc1-test-02`: **the saved game loaded** - Swiss Alps,
   the same company, 22 January 1930, €53,000
   (`05-reloaded-after-reboot.png`).
10. Exit from the menu; logs to `Results:`; `Sys:C/Shutdown`; pool stop;
    `vm.sh collect` exit 0, every file matched `COLLECT-MANIFEST.sha256`.

Logs: `logs/boot1-openloco.log`, `logs/boot2-openloco.log`, and the save
listings. The `[ERR]` lines in them (`Object has too few images for bogie
sprites!`, `scores.dat could not be found`, `save/autosave could not be found`
before the first autosave) come from upstream code and appear in the earlier
builds' logs too, including `a68ee724` from before this week's patches.

## Not covered by this run

- Saving **over** an existing file (the FAT32 concern) - deliberately avoided;
  the README tells users to save under new names.
- Sound: not listened to in this run (the slot had host audio, but nobody
  was listening). Music was confirmed on 2026-09-24 (backlog item 30); sound
  effects never.
- Performance, larger maps, other resolutions, a second start in the same boot.

## The defective candidate before this one

The first archive of this release (`10ff5c44`, port revision `e6382df`) failed
step 5: saving threw `basic_string_view::substr: __pos (which is 72) > __size
(which is 58)` and left an empty `.SV5` (`90-defective-e6382df-save-exception.png`,
`logs/defective-e6382df-openloco.log`). Cause and fix: backlog item 33. It
was never published.
