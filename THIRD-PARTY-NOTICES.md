# Third-party notices

## This repository

The scripts, tests, documentation and the headers of the patches are under the
MIT License ([LICENSE](LICENSE)). The patches themselves modify OpenLoco,
SDL3, fmt and yaml-cpp; their changes are offered under the licence of the
project they modify.

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

## Names

OpenLoco is an open-source re-implementation of Chris Sawyer's Locomotion.
This port is not affiliated with or endorsed by the OpenLoco project, Chris
Sawyer or Atari.
