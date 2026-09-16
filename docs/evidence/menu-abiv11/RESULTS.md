# OpenLoco on AROS: menu and a working map - ABIv11

2026-09-13, 22:31. Machine: **AROS One 64-bit (ABIv11)**, QEMU TCG, `one`,
`GFX=std`, started by this session. Unstripped binary, 15 game patches plus the
dependency patches, in `RAM:loco`. Original game assets: the `Locodata:` disk.

## Result: the game runs

| evidence | what it shows |
|---|---|
| `01-menu-and-title-map.png` | the Locomotion title screen with a rendered demo map, the menu globes, "AROS (x86-64)" in the corner |
| `02-title-map-animating.png` | the same screen a moment later - **a different part of the map**, so the render loop is running rather than stuck on one frame |
| `03-scenario-loaded-game-map.png` | **a loaded scenario**: the map of Great Britain with city names, the toolbar, the "New Company" window with its owner, £26 500, and the game clock at "7th January 1930" with speed buttons |

The third screenshot is the real milestone: not a title screen but running
gameplay with its interface and clock.

## How the 513 MB transfer was solved

**Problem:** the whole of `shared/` exceeded the vvfat limit -
`Directory does not fit in FAT16 (capacity 516.06 MB)`. `fat:32:` does not help
(QEMU builds FAT16 regardless), and a second `fat:` drive without `rw:` ended in
`Block node is read-only`.

**Solution: a real disk image instead of vvfat.**

```sh
dd if=/dev/zero of=~/Work/AROS/loco-assets.img bs=1m count=700
hdiutil attach -nomount -imagekey diskimage-class=CRawDiskImage loco-assets.img
diskutil partitionDisk /dev/diskN MBR MS-DOS LOCODATA 100%
cp -R <assets> /Volumes/LOCODATA/Locomotion
hdiutil detach /dev/diskN
```

The image has an MBR partition table and a single **FAT32** partition, so the
FAT16 limit does not apply. AROS mounts it as the volume `Locodata:` (`info`:
700.0M, 514.1M used, FAT32).

Attached as a **fourth IDE disk**, on the free `index=3`:

```
-drive file=loco-assets.img,format=raw,if=ide,index=3
```

`index=2` belongs to the CD-ROM - the temporary `/tmp/openloco-one-fat32.sh`
script put a second vvfat drive there, which is why it could not work.

**The shared `run-aros.sh` was not modified.** A separate copy,
`~/Work/AROS/run-aros-loco.sh`, only **adds** the drive.

### The split, as intended

- `RAM:loco` - OpenLoco, its `data/`, configuration, logs and saves (writable)
- `Locodata:Locomotion` - the original `Data/`, `ObjData/`, `Scenarios/` (read
  only)

**A deliberate deviation from "everything in RAM: eventually":** the assets stay
on the FAT32 disk rather than being copied into RAM:. Reasons: 513 MB in a
RAM disk of about 1003 MB would leave the game little room on a 2 GB machine,
and copying that under TCG would take many minutes on every start. The
instruction's prohibition concerned **writing from the guest onto vvfat** - and
here there is neither vvfat nor writing: the game only reads from `Locodata:`,
and everything it writes goes to `RAM:loco`.

The path comes from `RAM:loco/openloco.yml`:

```yaml
loco_install_path: Locodata:Locomotion
```

which stops the game asking for it interactively.

## Known noise in the log - caused by my transfer

```
[ERR] Unable to load the object '._Mac...', can't add to index
[ERR] Data c... (repeatedly)
```

macOS wrote resource-fork files `._*` onto the FAT32 volume next to every
object, and OpenLoco tries to load them as objects. **It does not block the
game** - menu, scenario and map all work - but it pollutes the log and the
object index.

Fix (on the host, with the image unmounted): remove `._*` and `.DS_Store` from
the volume, e.g. `dot_clean /Volumes/LOCODATA` before detaching.
**Unverified** - the screenshots were taken before that fix.

## What this result does not show

- **Performance.** Not measured. Under TCG the game responds, the title screen
  animates and the scenario loads - but there is no fps figure and it must not
  be guessed from screenshot delays.
- **Gameplay longer than a few tens of seconds**, building, saving and reloading
  state.
- **Audio.** `OpenALBase` is among the binary's requirements, but nothing played
  and QEMU starts without a host audio driver.
- **Mainline v1.** Everything above applies to ABIv11 only.
