# OpenLoco for AROS (x86_64, ABIv11)

Version `@VERSION@`
SHA-256 `@SHA@`

OpenLoco is an open-source re-implementation of Chris Sawyer's Locomotion.
This is a port of it to AROS. It is not made by the OpenLoco project and any
problem you find here is this port's to answer for until shown otherwise.

## What you need

- **AROS One 1.3, 64-bit (ABIv11).** Built and tested only there. It will not
  run on 32-bit AROS or on mainline ABI v1.
- **Your own copy of Chris Sawyer's Locomotion.** The game data is not included
  and cannot be: it is commercial. You need the installed game's files -
  `Data`, `ObjData`, `Scenarios`, `g1.DAT` and the rest.
- About 2 GB of RAM for the machine, and a hard disk you can write to; the game
  writes its config, saved games and screenshots next to itself.

## Installing

1. Copy this drawer somewhere writable, for example `Work:Games/OpenLoco`.
2. Put your Locomotion files where `openloco.yml` points, or edit that line.
   The default is `Locodata:Locomotion`.
3. From a Shell: `cd` into the drawer and run

       execute Run-OpenLoco

**Start it with `Run-OpenLoco`, not by typing `OpenLoco`.** The default Shell
stack is too small - 40 KB on a stock AROS One 1.3 - and the game then dies
part-way through drawing its first screen with

    Error: 0x8100000E - Stack extends out of range
    Function ... SoftwareDrawingContext::drawImage ...

`Run-OpenLoco` is two lines: it raises the stack to 1 MB and starts the game.
If you prefer to type it yourself, `stack 1048576` once per Shell does the
same. This is not a crash you did anything to cause, and it is not a data
problem - it is the stack.

The first run writes the rest of `openloco.yml` itself. Log lines go to the
Shell; redirect them with `OpenLoco >run.log` if you want to keep them, but
note that AROS's Shell does not understand `2>&1`, so error lines still appear
on screen.

## What works

Menu, scenarios, building track and stations, buying and running vehicles,
keyboard text entry, saving and loading, music and sound through OpenAL. Saved
games survive closing the program and rebooting the machine.

## What to expect, honestly

- **The renderer is the software one.** On AROS the OpenGL renderer is refused
  for the game's window, and where it has been forced it was about twenty times
  slower, because the GL available here is a software rasteriser. The software
  path is the fast one on this hardware.
- **Speed.** On an emulated machine the game held its own 40 frames per second
  cap at 640x480 on a small map. That is one measurement on one machine and is
  not a promise. Higher resolutions have not been measured in conditions worth
  quoting.
- **Writing over an existing file is the risky operation.** Saving over a save
  that already exists goes through a workaround in this port because the AROS
  FAT handler has damaged volumes doing it. Prefer saving under a new name.
  If you keep your saves on FAT32, keep a copy elsewhere.
- **Shut the machine down properly.** `Sys:C/Shutdown`, or the menu, before
  you close the emulator or cut the power. One session that ended without it
  left an orphaned cluster on the volume.
- The program leaves one unfreed signal bit on exit. It is reported by the
  Shell and is harmless as far as anything here has shown.

## If something goes wrong

Please include **the first line the program prints**, which looks like

    [INF] OpenLoco, 7f8c90cf+aros (df805ab on openloco-next+19)

That names the upstream commit it was built from, this port's revision, and
how many patches were applied - which is what anyone will ask for first.
`BUILD-INFO.txt`, `PATCHES.txt`, `BUILT-WITH.txt` and `DEPENDENCIES.txt` in
this drawer say the same thing in full, including the exact toolchain.

## Licence and credit

OpenLoco is licensed under the MIT licence; see the OpenLoco project for its
terms and its authors. This port adds the AROS changes listed in
`PATCHES.txt`. Chris Sawyer's Locomotion itself is not included, not free, and
not ours.
