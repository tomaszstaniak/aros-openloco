# Third-party notices

## This repository

The scripts, tests, documentation and the headers of the patches are under the
MIT License ([LICENSE](LICENSE)). The patches themselves modify OpenLoco,
SDL3, fmt and yaml-cpp; their changes are offered under the licence of the
project they modify. The MIT licence of this repository covers only the
port's own layer; it does not replace the licence of any component below.
Patch `20-upstream-4018-drawing-engine-cleanup` is not ours: it is a verbatim
copy of OpenLoco commit `6072709d` by MinerSheep (OpenLoco #4018), credited in
its header. It is not part of the release patch set, whose upstream pin
already contains it.

## What the AROS package contains

The `OpenLoco` binary is linked statically. Every component below is inside
it or ships next to it, and each licence text is copied into the package under
`Licenses/`.

| component | version | where | licence | text |
|---|---|---|---|---|
| OpenLoco | upstream `7f8c90cf` (v26.09+1), modified by the patches here | the program, `data/language/` | MIT, © 2018 OpenLoco developers (see upstream `CONTRIBUTORS.md`) | `OpenLoco-LICENSE.txt` |
| OpenGraphics objects | v0.1.12 | `data/objects/` | MIT, © OpenLoco | `OpenGraphics-LICENSE.txt` |
| SDL3 | 3.4.12 with the AROS backend from aros-development-team/contrib, modified by the patches here | linked in | zlib | `SDL3-LICENSE.txt` |
| fmt | 11.1.4, modified | linked in | MIT | `fmt-LICENSE.txt` |
| yaml-cpp | 0.9.0, modified | linked in | MIT | `yaml-cpp-LICENSE.txt` |
| sfl | 2.2.0 | linked in (header-only) | zlib | `sfl-LICENSE.txt` |
| libpng | 1.6.48, from the AROS One SDK | linked in | PNG Reference Library License v2 | `libpng-LICENSE.txt` |
| zlib | 1.3.1, from the AROS One SDK | linked in | zlib | `zlib-LICENSE.txt` |
| GCC runtime (libstdc++, libgcc) | GCC 10.5.0 | linked in | GPL-3.0 with the GCC Runtime Library Exception | no notice required |

**Not included:** OpenAL. The game calls the system's `openal.library`
through the SDK's link stubs; it is part of AROS One, not of this package.

**Not included and not distributable:** the assets of Chris Sawyer's
Locomotion (graphics, sounds, music, scenarios). You need your own copy of
the original game.

## The Raspberry Pi build

The `aros-aarch64-abiv1-raspi` binary (`openloco.aarch64-aros-raspi.lha`) is built with Clang
20.1.0 instead of GCC and against the SDK of the AROS Raspberry Pi nightly of
2026-10-29. Its SDL3 has the OpenGL backend compiled out. Besides the table
above, without the GCC runtime, it contains:

| component | version | where | licence | text |
|---|---|---|---|---|
| openal-soft | 1.19.1 with contrib's AROS diff (AHI backend) | linked in | LGPL-2.0-or-later | `openal-soft-COPYING.txt` |
| GNU libiconv | 1.19 with contrib's AROS diff | linked in | LGPL-2.1-or-later | `libiconv-COPYING.LIB.txt` |
| libc++, libc++abi, libunwind, compiler-rt builtins | LLVM 20.1.0 with the AROS diffs | linked in | Apache-2.0 WITH LLVM-exception | `LLVM-LICENSE.txt` |
| libpng, zlib | from the Raspberry Pi SDK | linked in | as above | as above |

The two LGPL libraries are linked statically. Their exact sources are the
release tarballs and contrib diffs pinned by checksum in
`scripts/fetch-deps.sh`; this repository's scripts rebuild them and relink the
game from source.

## Names

OpenLoco is an open-source re-implementation of Chris Sawyer's Locomotion.
This port is not affiliated with or endorsed by the OpenLoco project, Chris
Sawyer or Atari.
