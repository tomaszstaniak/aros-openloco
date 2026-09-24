# Map-edge "tile out of bounds" warnings - reproduction case

Recorded 2026-09-24. **Not diagnosed, not silenced.** This file exists so the
same conditions can be set up again and compared across builds.

## What was seen

Build `be6964e1` (`7f8c90cf+aros (2225f3d on openloco-next+20)`, ABIv11, pool
slot `v11-2`). With the main view scrolled to the edge of the `Aerophobia` map,
the log fills with

    [ERR] Attempted to get tile out of bounds! (-1, 84)
    [ERR] Attempted to get tile out of bounds! (-2, 85)
    ...

x from -1 to -3, y from 83 to 87 - 30 lines in the log file of each run. They
resumed as soon as this save was loaded after a guest restart, because the save
restores the same view.

The message comes from upstream's `Map/TileManager.cpp` (lines 327 and 384 at
upstream `7f8c90cf`). **That says where it is printed, not why the game asks
for those tiles**, and patch 25's scope (network start-up in `Socket.cpp`) does
not rule out every regression.

## The case

- save: `map-edge-view.SV5` (not published - saved games are built from
  the original Locomotion scenario data; kept privately), SHA-256
  `40fdd1abc1c49174c2894047bab168f0021ca3bc8ceabfa9ee1edbba5a58efad`
  (the `Aerophobiax-reg-2026-09-24` save from that run; company "UnnamedReg
  Transport", GBP 357,272 on load, March 1975, view at the map's edge)
- window 640x480, software renderer, stack 1 MB via `Run-OpenLoco`
- start the game, Load Game, pick this save, wait 60 seconds without input
- count the lines in `logs/openloco_*.log`:
  `search logs/#?.log "out of bounds" NONUM` in the drawer

## First test to run

The same case with the previous release build `a68ee724` (before patch 25 and
before `-lnet` was dropped), on the same slot, in the same boot. If the older
build logs the same lines at the same view, it is not a regression of those
changes. If it does not, it is.

After that, and only if the lines are still unexplained: whether upstream on
another platform logs the same at a map edge.

## Result of the first test (2026-09-24, slot v11-2, one boot)

| build | patch 25 / `-lnet` | lines after loading this save, 60 s, no input |
|---|---|---|
| `a68ee724` (`df805ab on openloco-next+19`) | before both | **30** |
| `a558320d` (`777be8e on openloco-next+20`) | after both | **30** |

The coordinate sets in the two logs are identical, line for line after
sorting. **The warnings predate patch 25 and the removal of `-lnet`; they are
not a regression of those changes.** A title-screen-only run of the new build
logged none. Why the game asks for tiles at x = -1..-3 at this view is still
not known; the next step, if it matters, is the same save on upstream OpenLoco
on another platform. The message was not silenced.

The save itself was also checked on this run: host -> ISO -> guest -> copied
into the game drawer -> loaded -> copied to `Results:` -> `collect`, and its
SHA-256 came back identical (`40fdd1ab...`).
