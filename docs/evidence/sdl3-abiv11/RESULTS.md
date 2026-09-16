# SDL3 + std::thread on AROS ABIv11 - run result

2026-09-12. Machine: **AROS One 64-bit (ABIv11)**, QEMU (TCG), `vm.sh one`,
started by this session. Toolchain `~/Work/AROS/toolchain` (GCC 10.5.0), SDK
`~/Work/AROS/sdk`. Nothing was built or run on mainline.

## What was built

SDL3 3.4.12 as a **static library**, outside the AROS build system: the file
list read straight out of `contrib/SDL3/main/mmakefile.src` (target
`SDL3-aros-staticlib`, `-DSDL3_AROS_STATIC`), sources being the upstream tarball
with contrib's `SDL3-3.4.12-aros.diff` applied.

**187 / 187 objects compiled**, `libSDL3_static.a` 2.6 MB. One fix along the
way: `src/time/unix/SDL_systime.c` includes `<langinfo.h>` unconditionally
although it only calls `nl_langinfo()` under `HAVE_NL_LANGINFO`. ABIv11 has no
`langinfo.h` in posixc (mainline does), so on ABIv11 that include is the only
thing that fails. Patch:
`patches/dependencies/sdl3-3.4.12-langinfo-guard.diff`, worth sending to
contrib.

The test linked with `-lSDL3_static -lGL -liconv -lpthread -lm`, 4.3 MB.

## Result - two runs

```
sdl3-smoke on AROS ABIv11
SDL compiled=3.4.12 linked=3.4.12 revision=SDL-release-3.4.12-0-gf87239e71
THREADS: PASS  [signalled=1 joinable=1 distinct_id=1 value=500500(expect 500500) hw_concurrency=0]
video driver: aros
  available driver 0: aros
  available driver 1: dummy
renderer: opengl
key down: scancode=4 key=97      <- run 2
key down: scancode=5 key=98
key down: scancode=6 key=99
key down: scancode=7 key=100
frames=300 elapsed_ms=49406 key_events=4 mouse_events=1 quit_event=0
fps=6.1
VIDEO: PASS
RESULT: PASS
```

### C++ threads work at runtime - this is settled

This was the open point from the previous assessment and it is now closed by
evidence rather than by inference. `std::thread` starts, `std::mutex` and
`std::condition_variable` carry the result across, `wait_for` wakes through the
predicate (not through the timeout), the worker has a different `thread::id`
than the main thread, and the value passed is correct. `join()` returns. Checked
through libstdc++, not through SDL's threads - those would say nothing about
libstdc++.

One detail: `std::thread::hardware_concurrency()` returns **0**. That is legal
("unspecified"), but code dividing by it or spawning that many threads gets
zero. OpenLoco does not use it - checked by grep.

### Window, renderer and texture work

An Intuition window opens on the Workbench screen, an
`SDL_PIXELFORMAT_XRGB8888` streaming texture is updated every frame and
presented. An animated gradient is visible (`shots/01-window-rendering.png`).
300 frames without an `SDL_UpdateTexture` error, a clean shutdown, and a return
to the Shell.

Video drivers SDL3 reports: `aros` and `dummy`. Selected: `aros`.

### Keyboard works, mouse partly

Run 2: four key presses (a/b/c/d) arrived with correct scancodes
(SDL_SCANCODE_A=4) and keycodes (97='a'). `mouse_events=1` - the cursor was not
moved deliberately, so that only shows the mouse channel is not dead; there was
no real test of dragging or buttons.

In run 1 `key_events=0` despite an ESC being sent. The program finished its 300
frames at that very moment, so ESC most likely arrived after the last
`SDL_PollEvent`. **I do not treat that as evidence either way** - the "close on
request" path remains unchecked, as does the window close gadget
(`quit_event=0` in both runs).

## What this test did NOT show

- **The software renderer.** `opengl` was selected and `setenv
  SDL_RENDER_DRIVER software` in the Shell did not change it - run 2 still
  reported `renderer: opengl`. Either the AROS `setenv` does not reach posixc's
  `getenv()`, or SDL3 reads the hint differently. The software path, the one
  OpenLoco keeps as its fallback, **was never exercised**. Force it with
  `SDL_SetHint()` in code next time.
- **Performance.** 6.1 fps at 320x240. That is a measurement **under QEMU/TCG**,
  with the OpenGL renderer probably going through software Mesa, and it includes
  my own overhead: the test generates 76 800 pixels per frame in C++. It is not
  a number about hardware or about SDL3 itself. OpenLoco runs at a higher
  resolution and needs many times more - **performance is now the main open
  item** and needs measuring on a real machine, comparing both renderers.
- **Audio.** `SDL_INIT_AUDIO` was never requested. The AHI backend is unchecked.
- **How the port will actually be linked.** This is a static library built
  alongside the AROS build system. It should eventually be contrib's
  `sdl3.library`, built in the ABIv11 tree - which still depends on resolving
  the missing contrib in the deadwood tree.

## How to repeat this

```sh
scripts/bootstrap.sh && scripts/fetch-deps.sh abiv11
scripts/build-sdl3.sh abiv11     # -> deps/abiv11/lib/libSDL3_static.a
scripts/build-smoke.sh abiv11    # -> build/abiv11/sdl3-smoke
# then: vm.sh start one, push.sh with DEPLOY=, copy AMIDEV:sdl3smoke RAM:, run it
```

The program writes its result to `PROGDIR:sdl3-smoke.log` rather than the
console - on the shared testbench the Shell may hold another session's output,
and a screendump cannot tell you whose. The log above was read with `type` in a
Shell this session opened itself, on a machine this session started itself.
