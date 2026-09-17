# AROS One / FAT32: O_TRUNC silently loses the write, and a volume gets damaged

2026-09-17. Machine **`loco`** (AROS One 64-bit, ABIv11) under QEMU TCG. Two
separate findings, deliberately kept apart because only one of them is
explained.

## Finding 1 - CONFIRMED: `O_TRUNC` over an existing file loses the data

Plain C, no game and no C++ runtime in the way:
`tests/fat32-overwrite/fat32-overwrite.c`, built by
`scripts/build-fat32-overwrite.sh`, run on a **throwaway 64 MB FAT32 image**
(`loco-scratch.img`, one file on it, verified clean by `fsck_msdos -n` first).

```
target: Locotest:ovtest.bin
step 1: create 307200 bytes
  wrote 307200
  closed
step 2: reopen existing with O_TRUNC and write 6 bytes
  opened
  wrote 6
  closed
step 3: read back
  read 0 bytes: ""
RESULT: FAIL - expected 6 bytes "small", got 0
```

Evidence: `o_trunc-data-loss.png`.

**Every call reports success.** `open(path, O_WRONLY | O_TRUNC)` succeeds,
`write()` returns 6, `close()` returns 0 - and the file reads back **empty**.
Nothing anywhere returns an error, so a program has no way to notice. Creating
a new file works (step 1), which is why writing new saves was never a problem.

**This is an AROS defect, not an OpenLoco one** - posixc or the FAT handler. It
affects any POSIX program that rewrites a file in place on a FAT volume, which
includes every C++ `std::ofstream` opened for output.

**It also explains the damaged `openloco.yml`.** The first `fsck_msdos` run
reported `/LOCO/OPENLOCO.YML starts with free cluster` and a
`cluster chain … ends with cluster marked free` - exactly the shape left behind
when the truncate frees the chain and the following write never links new
clusters in, while the directory entry keeps pointing at what is now free
space. `Config::write()` rewrites that file through an ofstream on every save.

**What this does NOT say:** the AROS Shell's own `copy` overwrites the same
file on the same volume without trouble (checked: 307,200 B replaced by 6 B at
6.1% CPU). `copy` uses `MODE_NEWFILE`. So the defect is in the POSIX path, not
in the handler's ability to overwrite as such. Which of the two layers is at
fault has **not** been established - that needs a test at the DOS packet level
(`Open(MODE_OLDFILE)` + `SetFileSize()`), which has not been written.

## Finding 2 - CONFIRMED but UNEXPLAINED: the volume gets damaged

`loco-home.img` (512 MB FAT32, the game install and its saved games):

| when | state |
|---|---|
| 19:47 | created fresh on the host, install copied in, cleanly detached |
| 19:51-20:14 | OpenLoco session 1: manual save, 9 autosaves, one freeze |
| 20:21 | `fsck_msdos -y` repaired it; a verifying `-n` run reported **no warnings**, 227 files |
| 20:22-20:41 | OpenLoco session 2: save reloaded, an overwrite save that succeeded, more autosaves, quit via the close gadget |
| 20:56-21:04 | OpenLoco session 3: **hung idle before the title screen, then the whole guest froze** - pointer stopped, CPU 3% |
| 21:04 | `fsck_msdos -n`: **`FAT[0]` is 0x0, should be 0xFFF8** + **112 orphaned clusters** |

Only AROS wrote to that volume between 20:21 and 21:04. The image in that state
is kept as `~/Work/AROS/loco-home-wedged-20260917.img`; the check output is in
`fsck-after-session-2.txt`.

### Two controls, both of which came back clean

Both on the throwaway image, both ending with QEMU stopped the same way as the
damaged sessions - that is, **without** a clean guest shutdown:

| run | what it did | `fsck_msdos -n` afterwards |
|---|---|---|
| control | mounted the volume, `info` and `list` only, **no writes** | **clean** (`control-run-read-only.png` shows `read/write FAT32`, 0 Errs) |
| O_TRUNC probe | created a 300 KB file, truncated and rewrote it, wrote a log | **clean**, 3 files |

So the damage is **not** explained by mounting the volume, nor by stopping QEMU
without a guest shutdown, nor by the simple truncate-and-rewrite sequence. All
three are ruled out.

### What is left, untested

The candidate this points at is **deletion churn**: the game's autosave
rotation deletes old files (`[INF] Deleting old autosave: …` appears in
`run2.log`), and the damaged volume had seen nine autosaves written and several
deleted, about 10 MB of traffic, alongside directory creation. None of that is
in either control.

**What would close it:** extend the probe to do what the game does - create,
delete and recreate files in a loop, in a subdirectory - and check the volume
after each stage. Also worth measuring: whether `FAT[0]` is zeroed the moment
the handler first *writes* anything, which a single-write probe would answer.

Until then, state it as it is: **a FAT32 volume written by AROS One acquired a
zeroed `FAT[0]` and orphaned clusters twice, and the cause is not identified.**
Do not keep anything valuable only on such a volume.

## Consequence for this port

Saved games on a FAT32 disk are not safe, for a reason that has nothing to do
with OpenLoco. The realistic options, in order of how much they are worth:

1. **Keep saves on the guest's own native volume** (the AROS filesystem on
   `aros-loco-hd.qcow2`) rather than on a FAT32 image. Loses host-side
   inspection, which is why FAT32 was chosen in the first place.
2. **Report finding 1 upstream to AROS.** It is small, reproducible, and the
   probe is ready to attach.
3. Make the game write saves the safe way - to a new file, then swap - which
   sidesteps the POSIX truncate path. That is a workaround in the wrong layer,
   but it is the only one this project controls.
