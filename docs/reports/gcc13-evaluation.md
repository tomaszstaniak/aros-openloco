# GCC 13.4 for ABIv11: evaluated, not adopted for the release

2026-09-24. Question: `aros-skia` used a newer GCC. Does it remove any of the
GCC 10 workarounds here, and should the OpenLoco release switch to it?

**Decision: the release stays on the verified AROS One SDK toolchain,
GCC 10.5.0.** No compiler change without a concrete reason and a full
re-verification; neither exists yet.

## The toolchain that was used in aros-skia

| | |
|---|---|
| compiler | GCC **13.4.0**, binutils 2.45, target `x86_64-aros` |
| ABI | **ABIv11** (AROS One headers, `aros-v11.specs`) |
| built from | AROS ABIv11 sources at `e33ca77d`, a local build on one Mac |
| extra requirements | `-specs=aros-v11.specs`, `-Wl,-u,__cxa_pure_virtual`; a libgcc patch (`0001`) so the unwinder's `dwarf_reg_size_table` is filled - without it every `throw` aborts |
| checked on AROS | small C++20 programs with throw/catch and threads, on a pool v11 slot |
| not checked | `-static-libstdc++`, large programs, any build machine but that one |

How aros-skia used it: **only** as a compile probe of Skia m154 (835 of 847
sources compiled; nothing linked or run). Its released Skia m124 was built with
GCC 10.5.0 - the same toolchain as this port.

## What it would remove here

| workaround | still needed with 13.4? | why |
|---|---|---|
| patch 04 `gcc10-using-enum` | **no** | `using enum` exists from GCC 11 |
| patch 05 `gcc10-span-from-static-vector` | **probably no** | the old `contiguous_range` detection is a GCC 10 libstdc++ limitation; not compiled to confirm |
| patch 02 `wide-strings-optional` | **yes** | a libstdc++ configuration choice, not a compiler version: the 13.4 build also has `_GLIBCXX_USE_WCHAR_T` undefined (read in its `c++config.h`) |
| `fmt-11.1.4-aros-nowstring.diff` | **yes** | same reason as patch 02 |

Everything else is about AROS headers, bsdsocket, OpenAL or SDL3, not the
compiler.

## Why not switch now

- Two small patches out of twenty-two would go; neither causes a known problem.
- Every tested result in this repository - gameplay, save/load, shutdown,
  audio, the resize fix - was obtained with GCC 10.5 binaries. A switch makes
  all of it unverified again.
- The C++ dependencies (fmt, yaml-cpp) would have to be rebuilt with it, and
  the static libstdc++ that the game links has not been exercised under 13.4
  in a program of this size.
- The toolchain exists on one machine, built locally; a release built with it
  could not be reproduced from the AROS One SDK.

Revisit when the toolchain is published or adopted by AROS One, or when a
GCC 10 limit blocks a needed change.

## A related hypothesis for mainline v1 (not tested)

The libgcc `0001` fix (the unwinder's register-size table left at zero, so
`throw` aborts) is a strong candidate for the C++ exception abort that stopped
the mainline v1 work (`tests/cxx-runtime`). That is a **hypothesis**: v1 is out
of scope for this release and the fix has not been tried on v1.
