# OpenLoco on AROS ABIv11 and mainline v1

> **Historical document.** This is the feasibility assessment as of 2026-09-12,
> before the port was built, linked or run. It is kept because it records why
> the decisions were made. For the current state see
> `evidence/menu-abiv11/RESULTS.md` (the game runs: menu, title screen and a
> loaded scenario) and `backlog/open-questions.md`.

Assessment of 2026-09-12. Scope: native AROS x86_64, two separate ABIs.
**Primary target: ABIv11.** mainline v1 as the second target.

Backlog of open items: `docs/backlog/open-questions.md`.
Shared rules: `../../AGENTS.md`, platform facts: `../../docs/platform/`.

## Verdict

**The port is feasible and does not require writing a backend from scratch.**
Since December 2025 the game has been fully reimplemented in C++ - there are no
hooks into the original `loco.exe` and no x86 code, which is what blocked a port
for a decade. All hardware access goes through SDL3, and AROS has a native SDL3
port in contrib.

| | ABIv11 (primary) | mainline v1 |
|---|---|---|
| .cpp files compiling unchanged | **366 / 394** | **379 / 394** |
| SDL3 | not in the deadwood tree | present in `contrib/SDL3` |
| OpenAL in the SDK | `libopenal.a` present, but without HRTF | `AL/` headers present, library missing |
| iconv in the SDK | present | missing |

The two ABIs are close to each other. The difference is 13 files that need
`std::wstring_view` on ABIv11.

Repository: https://github.com/OpenLoco/OpenLoco
Commit: `af445f8dc6632c6341fc7b26c3246685406e6815` (2026-09-10), version 26.08.

## What OpenLoco actually needs

From `thirdparty/CMakeLists.txt`, not from the README:

- **SDL3** (`find_package(SDL3 REQUIRED CONFIG)`) - the only hard GUI
  dependency.
- **OpenAL** - all audio; `src/Audio/src/AudioEngine.cpp` uses `AL/al.h`,
  `AL/alc.h`, `AL/alext.h`.
- **libpng + zlib** - present in both SDKs, **but `libpng.a` and `libz.a` are
  link stubs** into `png.library` and `z1.library`. The link has to use
  `-lpng_nostdio -lz.static` (png before z), which both SDKs have.
  **Checked on the machine 2026-09-13:** writing and reading a PNG through the
  game's own callbacks, a pixel-for-pixel round trip, with no reference to
  `Z1Base`/`PNGBase` in the binary - `tests/png-smoke/`. An earlier version of
  this assessment simply said both SDKs have them, which was too strong.
  Details: `../../docs/platform/libraries.md`.
- **fmt 11.1.4, sfl 2.2.0, yaml-cpp 0.9.0** - fetched by CMake, plain C++.
- **TBB** - through `<execution>`. More below; it is not a one-line change.
- **libzip** - **not used.** The README lists it, but there is not a single
  `#include <zip.h>` anywhere in the tree. A dead entry in the documentation.
- **breakpad** - MSVC only.

CMake configuration with the ABIv11 toolchain gets through compiler detection,
C++20, `Threads` and `__GLIBCXX__`, and stops exactly at `find_package(SDL3)`.

## State of the toolchains

Both ABIs have **GCC 10.5.0**. Upstream builds with GCC 13+.

```
__cpp_concepts 201907   __cpp_lib_concepts 202002   __cpp_lib_ranges 201911
__cpp_lib_span 202002   __cpp_lib_jthread 201911    __cpp_lib_atomic_ref 201806
_GLIBCXX_HAS_GTHREADS 1
```

**GCC 10.5.0 is enough only after adapting the code.** The macros above describe
the library, not the language: `using enum` is C++20 introduced only in GCC 11,
and in four OpenLoco files it ends in a syntax error (`CompanyAi.cpp:3496`,
`:3562`, `:3604` and further). No flag works around it - those places have to be
rewritten or the toolchain raised. AROS carries GCC patches up to 16.2.0 in
`tools/crosstools/gnu/`, so raising it is not a dead end.

`std::bit_cast` and `std::format` are missing (GCC 11+), but OpenLoco uses
neither - checked by grep across all of `src/`.

### Threads: verified at runtime on ABIv11

`_GLIBCXX_HAS_GTHREADS 1` on both ABIs, and
`tools/crosstools/gnu/gcc-15.2.0-aros.diff` sets `thread_file=posix` and
`LIBSTDCXX_PTHREAD "pthread"`. Those were only indications; **it was settled by
running on the AROS One machine (ABIv11)**: `std::thread` starts, `std::mutex`
and `std::condition_variable` carry the result across, `wait_for` wakes through
the predicate, the worker has a different `thread::id`, and `join()` returns.
Details and log: `docs/evidence/sdl3-abiv11/RESULTS.md`.

Caveats: verified **on ABIv11 only** - mainline remains unconfirmed - and
`std::thread::hardware_concurrency()` returns `0` there (OpenLoco does not use
it).

## ABIv11: no wchar_t in libstdc++

```
abiv11:  #define _GLIBCXX_USE_C99_WCHAR _GLIBCXX11_USE_C99_WCHAR
abiv1:   #define _GLIBCXX_USE_C99_WCHAR _GLIBCXX11_USE_C99_WCHAR
         #define _GLIBCXX_USE_WCHAR_T 1
```

The ABIv11 libstdc++ was built **without** `_GLIBCXX_USE_WCHAR_T`, so
`std::wstring` and `std::wstring_view` do not exist. Mainline has them. It shows
up in two places:

1. **fmt 11.1.4**, `format.h:1271` - one line in a `wchar_t` helper OpenLoco
   never calls. The header is included everywhere, so that single line broke 334
   files.
2. **`src/Utility/include/OpenLoco/Utility/String.hpp:14`** -
   `std::string toUtf8(const std::wstring_view& src)`. A Windows helper. After
   fixing fmt, 13 files still catch on it.

**Do not start by rebuilding libstdc++.** A local patch against the pinned fmt
version (`patches/dependencies/fmt-11.1.4-aros-nowstring.diff`, a guard on
`_GLIBCXX_USE_WCHAR_T`) settles point 1 immediately and lets us see what is
really blocking the game - which proved true, because only afterwards did
`wstring_view` and `ALC_HRTF_SOFT` surface. Rebuilding the standard library has
a far wider scope, affects every future C++ port, and needs a separate check of
whether AROS ABIv11 has the full set of wide-character functions on the C side.
That is a separate decision, not a step in this port.

## Compile probe result

Compilation to object files, no linking. 394 `.cpp` files from `src/` (skipping
`Platform.Windows.cpp`, `Platform.Macos.mm`, `Crash.cpp` - backends that are not
ours). Flags from `cmake/OpenLocoCommon.cmake`:
`-std=c++20 -fno-char8_t -fstrict-aliasing -O1 -DFMT_HEADER_ONLY=1`.
SDL3 from the upstream 3.4.12 headers **with contrib's AROS patch applied**. The
only change outside the game's sources is the fmt patch described above.

| | ABIv11 | mainline v1 |
|---|---|---|
| Compiler | GCC 10.5.0, `~/Work/AROS/toolchain` | GCC 10.5.0, `/Volumes/arosmain/toolchain-mainline` |
| SDK | `~/Work/AROS/sdk` | `/Volumes/arosmain/build/bin/pc-x86_64/AROS/Developer` |
| **OK** | **366 / 394** | **379 / 394** |
| Failures | 28 | 15 |
| `std::wstring_view` in `Utility/String.hpp` | 13 | - |
| `using enum` (GCC 11+) | 4 | 4 |
| `OPENLOCO_PLATFORM` unknown platform | 4 | 4 |
| `sfl::static_vector` conversions | 4 | 4 |
| the `listen` macro from bsdsocket | 1 | 1 |
| `full path exe retrieval` | 1 | 1 |
| `ALC_HRTF_SOFT` not declared | 1 | - |
| missing `iconv.h` | - | 1 |

An earlier version of this probe reported 60/394 and 365/394. Both numbers were
wrong: `-fno-char8_t`, which upstream sets in CMake, was missing, so the probe
invented 15 `char8_t` conversion errors the real build does not see, and ABIv11
did not have the fmt patch. The numbers in the table come from the probe with
aligned flags.

Per-file logs are in `docs/evidence/compile-probe/abiv11/` and
`docs/evidence/compile-probe/mainline-v1/`, with the summary in
`docs/evidence/compile-probe/summary.json`. Script: `scripts/compile-probe.py`,
dependencies: `scripts/fetch-deps.sh`.

**No linking and no run in QEMU were performed.** These numbers describe object
files, not a working program. `366/394` does not mean "93% of the port is done"
- it only means that many translation units pass through the compiler.

## What needs work

0. **SDL3 on ABIv11 - built and run 2026-09-12.** A static library from
   contrib's file list, 187/187 objects; window, streaming texture and keyboard
   work on AROS One. That did not remove item 1: it is a build alongside the
   AROS build system, not contrib's `sdl3.library`. Open after that test: the
   software renderer (`opengl` was selected), performance (6.1 fps at 320x240
   under TCG) and audio through AHI.
   Full result: `docs/evidence/sdl3-abiv11/RESULTS.md`.
1. **SDL3 for ABIv11 does not exist as a build in the tree.** `contrib/SDL3` is
   a complete native backend: video through `SDL_arosframebuffer`, audio through
   AHI, threads, timer, joystick, clipboard, message box, locale, OpenGL through
   `SDL_arosopengl`, plus the software and OpenGL renderers. It is in the
   mainline tree and builds as `sdl3.library` through the mmakefile, depending on
   `workbench-libs-mesa-linklib` and `development-libiconv`. **The deadwood tree
   (`~/Work/AROS/aros-src`) has no contrib at all.** Neither SDK has SDL3
   headers - only SDL1.2 and SDL2. This is the largest item in the whole port and
   it concerns the primary target. To be decided: put mainline contrib into the
   ABIv11 tree, or build SDL3 outside the AROS build system.
2. **`std::wstring_view` in `Utility/String.hpp:14`** - 13 files on ABIv11.
   `toUtf8(const std::wstring_view&)` is a Windows helper; to be guarded.
3. **`using enum`** - 4 files on both ABIs, `CompanyAi.cpp` and its neighbours.
   Either rewrite them, or use a newer GCC.
4. **`<execution>` and TBB - not one line.** There is a single call
   (`src/OpenLoco/src/Viewport.cpp:187`,
   `std::for_each(std::execution::par, …)`), but the `#include <execution>` in
   that file (line 26) has to go or be guarded too, and TBB has to be removed on
   the CMake side: `CMakeLists.txt:76` sets `HAS_LIBSTDCPP`,
   `thirdparty/CMakeLists.txt:85-88` then looks for TBB and warns when it is
   missing, and `src/OpenLoco/CMakeLists.txt:758` adds `TBB::tbb` to the link.
   Four places, not one.
5. **OpenAL.** On ABIv11 `AudioEngine.cpp` does not know `ALC_HRTF_SOFT` - the
   SDK carries openal-soft 1.19.1 (2018), without that extension. Either guard
   HRTF or raise openal-soft. On mainline the library is missing entirely: the
   `AL/` headers are there, but `contrib/MultiMedia/libs/OpenAL` is not built.
6. **iconv on mainline.** `iconv.h` is not in the SDK, so
   `src/Utility/src/String.cpp` fails to compile on mainline while it compiles
   on ABIv11 (which has `iconv.h` and `libiconv.a`). This is not a gap in AROS
   but an unbuilt piece of contrib.
7. **Platform identification.** `src/Version/include/OpenLoco/Version.hpp:46`
   ends in an `#error` because it does not know `__AROS__`. The branch is three
   lines and is worth sending upstream.
8. **`src/Platform/src/Platform.Posix.cpp`** - `#error "Platform does not
   support full path exe retrieval"`. AROS needs its own branch (`PROGDIR:`),
   and likewise for the configuration paths, which on AROS do not go through
   XDG.
9. **The `listen` macro.** The bsdsocket headers define `listen` as a macro,
   which breaks `Network/Socket.h:65` and `Socket.cpp:415`. Either `#undef` it
   or rename the method; networking is not needed for a first run.
10. **`sfl::static_vector`** - 4 files on both ABIs, conversions that do not
    compile under GCC 10. Local.
11. **Game assets.** OpenLoco requires files from the original Chris Sawyer's
    Locomotion. The ELF alone achieves nothing.

## Things that turned out favourably

- **The software renderer is already provided for in the code.**
  `src/OpenLoco/src/Graphics/SoftwareDrawingEngine.cpp:54` tries the default
  renderer and line 60 explicitly asks for `"software"` as a fallback. That is
  exactly the gap that was a startup risk in GrafX2. It is not here.
- **Contrib's AROS patch applies to upstream 3.4.12 without a single rejected
  hunk.** The SDL3 port is maintained: an update to 3.4.12 and an m68k build fix
  on 2026-07-28.
- **The game draws into a software buffer and presents it as a texture** - it
  needs no 3D acceleration. The original's requirements are from 2004.

## Recommended order

1. **A minimal SDL3 window on ABIv11.** Build SDL3 and run the simplest program
   that opens a window and receives events. That settles the largest unknown in
   the port and, along the way, checks threads in action for the first time.
2. Only then the game's code: `wstring_view`, `using enum`, the `__AROS__`
   branches in `Version.hpp` and `Platform.Posix.cpp`, `<execution>`/TBB in its
   several places, HRTF, the `listen` macro, `sfl`.
3. **A full link.** Only that will show whether the SDK holds stubs instead of
   real symbols - compiling does not settle it.
4. A run in QEMU, separately on each ABI, on a matching system. Report the
   result with the machine's name.

Outlook: **high feasibility**. The main unknown is not the game's code but SDL3
on ABIv11 and the behaviour of threads at runtime. Until there is a link and a
run, there is no basis for quoting a number of days.
