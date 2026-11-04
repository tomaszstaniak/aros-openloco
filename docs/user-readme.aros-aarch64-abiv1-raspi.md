# OpenLoco for AROS on the Raspberry Pi (aarch64, ABIv1) - test build

Version `@VERSION@`
SHA-256 `@SHA@`

OpenLoco is an open-source re-implementation of Chris Sawyer's Locomotion -
https://github.com/OpenLoco/OpenLoco and https://openloco.io. This is a port
of it to AROS; its own page is https://github.com/tomaszstaniak/aros-openloco.
It is not made by the OpenLoco project, and any problem you find here is this
port's to answer for until shown otherwise.

**This is a test build.** It has been run only on an emulated Raspberry Pi 3
(QEMU), never on a real Raspberry Pi. Read "What to expect" before you rely on
it with saves you care about.

## What you need

- **AROS for the Raspberry Pi (aarch64, ABIv1)**, a nightly from 2026-10-29 or
  later. Built against that nightly's SDK and tested only on it. It will not
  run on x86 AROS or AROS One; those have their own build.
- **Your own copy of Chris Sawyer's Locomotion.** The game data is not included
  and cannot be: it is commercial. You need the installed game's files -
  `Data`, `ObjData`, `Scenarios`. See "Getting the Locomotion files" below.
- About 100 MB of free RAM (the game used about 80 MB in testing on a 1 GB
  machine), and a volume you can write to: the game writes its config, saved
  games and screenshots next to itself.

The program contains everything else it needs: SDL3, OpenAL Soft, the C++
runtime and iconv are linked into it, so no extra libraries have to be
installed.

## Getting the Locomotion files

Like OpenLoco itself, this port needs the files of the original **Chris
Sawyer's Locomotion** - graphics, sounds, music, vehicles and scenarios. They
are commercial and cannot be distributed with OpenLoco or with this port. The
OpenLoco project's own advice applies here unchanged (see
[Downloading the game](https://github.com/OpenLoco/OpenLoco#2-downloading-the-game-pre-built)
in its README): buy the game, for example on
[Steam](https://store.steampowered.com/app/356430/) or
[GOG.com](https://www.gog.com/game/chris_sawyers_locomotion).

Neither store has an AROS client, so the files travel through another
computer:

1. **Install the game on another computer** with the Steam or GOG client.
2. **Find its installation folder** - in Steam: right-click the game →
   *Manage* → *Browse local files*; in GOG Galaxy: the game's settings →
   *Manage installation* → *Show folder*. It is the folder that contains the
   drawers `Data`, `ObjData` and `Scenarios`; `Data/g1.DAT` is the file OpenLoco
   looks for to recognise it. The copy used for testing this port was about
   510 MB.
3. **Copy that whole folder to the AROS machine** - onto the SD card, a USB
   stick, or over the network - for example to `Work:Games/Locomotion`. The game only reads these files, so a
   read-only volume is fine. The case of file names does not matter on AROS.
4. **Tell the game where it is**, in one of two ways:
   - edit `openloco.yml` in the `OpenLoco` drawer:
     `loco_install_path: Work:Games/Locomotion`
   - or keep the default `Locodata:Locomotion` and make it point there:
     `assign Locodata: Work:Games` (put that line in `S:User-Startup` to keep
     it after a reboot).

Check it from a Shell: `list Work:Games/Locomotion/Data/g1.DAT` must show the
file. If the path is wrong, the game reports that the folder is missing
`Data/g1.DAT` - check the path before looking for anything else.

## Installing

1. **Extract the archive on another computer** and copy the drawer it
   creates, `OpenLoco`, onto the Pi - onto its SD card or a USB stick, for
   example to `Work:Games/OpenLoco`. AROS for the Raspberry Pi has no `lha`
   or `unzip` of its own, which is why there is a `.zip` next to the `.lha`:
   macOS and Windows open a `.zip` without extra tools. If you have installed
   an `lha` on the Pi, `lha x openloco.aarch64-aros-raspi.lha` there works
   too.
2. Make your Locomotion files reachable at the path in `openloco.yml`
   (default `Locodata:Locomotion`), as described above.
3. From a Shell: `cd` into the drawer and run

       execute Run-OpenLoco

**Start it with `Run-OpenLoco`, not by typing `OpenLoco`.** The default Shell
stack is too small for the game; `Run-OpenLoco` raises it to 1 MB, checks that
it is run from the right drawer with nothing missing, and starts the game. If
you prefer to type it yourself, `stack 1048576` once per Shell does the same.

`Run-OpenLoco` also sets the program's execute bit, which a copy through a
FAT volume or an extractor on another computer can lose; without it the Shell
says `file is not executable`. If you start the game yourself, run
`protect OpenLoco +e` in the drawer once.

The first run writes the rest of `openloco.yml` itself. Log lines go to the
Shell; redirect them with `OpenLoco >run.log` if you want to keep them.

## Sound

OpenLoco plays through OpenAL, which this build carries itself and which
outputs through AHI **unit 0**. Set unit 0 to your output in `Prefs/AHI`.
In testing, sound only reached AHI's silent **VOID** unit, because HDMI audio
cannot be used on the emulator: whether you hear music and effects on a real
Pi is **not known yet** - please report it.

## What was tested

On an emulated Raspberry Pi 3 (QEMU raspi3b, 1 GB, AROS nightly 2026-10-29),
with this release as published: the `.zip` extracted on another computer and
the drawer copied to the Pi, started through
`Run-OpenLoco`, the title menu, a scenario, track, a station and a train built
and running, keyboard text entry, saving under a new name, a clean exit, a
reboot, and the save loaded again. On the SMP kernel: start, a scenario and a
clean exit.

## What to expect, honestly

- **Only emulated so far.** Nothing has been run on a real Raspberry Pi.
  Speed, sound, USB input and SD card behaviour on real hardware are unknown.
- **Speed.** On the emulator the game held its own 40 frames per second cap in
  a 640x480 window on a small map, on one core and on SMP. That says little
  about a real Pi 3, 4 or 5 and is not a promise. Larger windows and maps have
  not been measured.
- **The renderer is the software one.** This build has no OpenGL; the game
  draws with SDL's software renderer, as it does on x86 AROS.
- **Writing over an existing file is the risky operation.** On x86 AROS the
  FAT handler has damaged volumes while saves were rewritten in place. That has
  not been tried on the Pi. Prefer saving under a new name, and keep copies of
  saves you care about.
- **Shut the machine down properly** before you cut the power.
- The program leaves one unfreed signal bit on exit. It is reported by the
  Shell and is harmless as far as anything here has shown.

## If something goes wrong

Please include **the first line the program prints**, which looks like

    [INF] OpenLoco, @VERSION@

That names the upstream commit it was built from, this port's revision, and
how many patches were applied - which is what anyone will ask for first.
`BUILD-INFO.txt`, `PATCHES.txt`, `BUILT-WITH.txt` and `DEPENDENCIES.txt` in
this drawer say the same thing in full, including the exact toolchain.

## Licence and credit

OpenLoco is licensed under the MIT licence by the OpenLoco developers; see
github.com/OpenLoco/OpenLoco for its authors. This port adds the AROS changes
listed in `PATCHES.txt`. The drawer `Licenses/` holds the licence of every
component the program contains, with a summary in
`Licenses/THIRD-PARTY-NOTICES.md`. Chris Sawyer's Locomotion itself is not
included, not free, and not ours.
