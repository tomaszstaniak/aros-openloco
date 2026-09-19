# Diagnostic patches - not part of the build

`scripts/bootstrap.sh` applies only `patches/openloco/*.diff`. The patches here
are instrumentation written for backlog item 21 (the second-start hang) and are
**not** applied to normal builds.

They were moved out on 2026-09-20 because instrumentation was itself suspected
of changing the behaviour it observed: with the dense markers of patch 19 in
place the hang did not occur, and a later A/B/A comparison could not reproduce
it with or without them. A release build must not carry them either way.

| patch | what it adds | written against |
|---|---|---|
| `18-aros-startup-markers.diff` | numbered markers around startup (10-16) and shutdown (50-58), printed with an immediate flush and appended to `Locohome:loco/markers.txt`; a `no-audio` file that skips OpenAL initialisation entirely | the series `01`-`17` |
| `19-aros-audio-init-markers.diff` | markers 20-37 around every call inside OpenAL initialisation; logs the `no-audio` switch's path and `exists()` result; reports failed `fprintf`/`fclose` | `01`-`17` + `18` |

**They do not apply on top of the current series as it stands**: patches 20
and 21 changed `exitCleanly()`, which 18 also edits. To use them again, apply
`01`-`17`, then 18 and 19, then re-derive 20 and 21 on top - or rewrite 18
against the current series.

The binaries built with them are archived by SHA-256 in
`~/Work/AROS/loco-variants/builds/`:

- `d8df9ba5…` - variant A, patches 01-18
- `02fc1ca5…` - variant B, patches 01-19
- `8c11ae86…` - variant C, patches 01-19 + 20 + 21 (21 with markers 61-63)
