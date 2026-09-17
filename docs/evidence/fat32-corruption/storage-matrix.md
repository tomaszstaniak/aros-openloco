# Is a FAT32 volume on AROS trustworthy storage? - the measurement

2026-09-17, 22:11-22:36. Machine **`loco`** (AROS One 64-bit, ABIv11), QEMU
TCG. Probe: `tests/fat32-storage/`, built by
`scripts/build-fat32-storage.sh`.

**Four cases, four separate throwaway 64 MB images**, one case each, so that
`fsck_msdos` afterwards says something about that case alone. Every image was
built by `scripts/make-scratch-image.sh`, which prints its baseline - all four
started **clean**.

**The step every earlier run skipped:** the files are read back and compared
byte by byte **in a later boot**, after the guest has been restarted. The probe
recomputes what each file should hold from its number, so it cannot be fooled
by whatever happens to be on the disk, and the write pass leaves `mode.txt`
behind so the verify pass cannot be given the wrong expectation.

## Results

| case | what it did | write pass | `fsck` after write | **verify after restart** | `fsck` after verify |
|---|---|---|---|---|---|
| create | 8 new files, 1-8 KB | **PASS** | clean | **PASS** - all 8 byte-identical | clean |
| overwrite | 4 files at 64 KB, then rewritten at 1 KB through `O_TRUNC` | **FAIL 4/4** - 0 bytes instead of 1024, every time | clean | **FAIL 4/4** - still 0 bytes | clean |
| delete | 8 files created, the 4 even ones removed | **PASS** | clean | **PASS** - even ones gone, odd ones byte-identical | clean |
| rotate | 12 files written, the oldest dropped so only 3 are ever kept - what the game's autosave does | **PASS** | clean | **PASS** - r00-r08 gone, r09-r11 byte-identical | clean |

Evidence: `matrix-write-create-overwrite.png`,
`matrix-verify-create-overwrite.png`, `matrix-write-delete-rotate.png`,
`matrix-verify-delete-rotate.png`.

## What this establishes

**1. `O_TRUNC` over an existing file loses the data - deterministically for
this probe.** Four out of four on a freshly built volume, and the loss
**survives a restart** - the files are still 0 bytes in a later boot, so this
is permanent destruction and not a caching artefact. Every call reports success
throughout.

**But the game is not deterministic on the same primitive, and that matters.**
OpenLoco saves through `fopen(path, "wb")`, which is the same O_TRUNC path, and
it behaved differently on the two occasions it was watched: once the guest
wedged mid-save (2026-09-17 20:14), and once it **succeeded** (20:37). The
proof that it succeeded is on disk: `Sandbox Settler.SV5` is now 939,772 bytes
while the copy taken from that volume at 20:21 is 952,272 bytes, and the
reloaded game showed the expected state. So the file really was rewritten with
valid, smaller content.

Which means the defect is **not** "O_TRUNC always destroys the file". Something
separates the probe's case from the game's, and the obvious candidates are the
sizes involved - the probe shrinks 64 KB to 1 KB, the game shrank 952 KB to
940 KB - and how many clusters the truncate has to free. That is untested.

(Incidentally, this is the second sighting of stale FAT metadata: the file's
directory entry still says 20:08, the time of the save *before* the one that
rewrote it.)

**2. Creating, deleting and rotating files is reliable in this scope.** Content
read back after a guest restart is byte-identical in all three cases. This is
the first result in this project that says anything about durability rather
than about a write appearing to succeed.

**3. None of the four cases reproduced the `FAT[0]` corruption.** All eight
`fsck` runs - after the writes and again after the verification - came back
clean on all four volumes. The rotation case was the leading suspect and it
passed.

## What is still unexplained, and what differs

`loco-home.img` twice acquired a zeroed `FAT[0]` and orphaned clusters. Six
runs have now failed to reproduce it. What still separates them from the
damaged volume, none of it tested:

| | probe runs | the damaged volume |
|---|---|---|
| volume size | 64 MB | 512 MB |
| files | at most 12 | 227 |
| largest file | 8 KB | 950 KB (a saved game) |
| bytes written | tens of KB | about 10 MB |
| subdirectories | none | `save/`, `save/autosave/`, `landscape/`, `objects/` |
| writer | one C program, `write()` | the game, C++ `ofstream` and its own stream writer |
| session | under two minutes | three sessions over an hour, one ending in a wedged guest |

These are **differences from the damaged case, not a mechanism**. Nothing here
says how any of them would zero `FAT[0]`; they are simply the variables that
were never exercised. The next probe cases change **one at a time**: a ~1 MB
file, a file written into a subdirectory, and the same cases on a 512 MB
volume.

## What this means for saving a game

- **Never overwrite a save.** That path destroys the file, silently, every
  time. Always type a new name, which works now that text input does.
- **Autosave rotation is safe as far as this measures** - it writes new files
  and deletes old ones, and both survived a restart intact.
- **Keep a host-side copy anyway.** The `FAT[0]` corruption has a cause that
  six runs have not found, and the one time the game hit a damaged volume it
  wedged the whole guest.
