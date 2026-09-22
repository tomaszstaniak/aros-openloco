# Draft report: SDL3 AROS backend refuses `opengl` for a hidden window, silently

**Status: DRAFT, not sent. Sending is a separate decision and has not been
taken.** Written 2026-09-23 against `aros-development-team/contrib`, SDL3 port.
Nothing here has been posted anywhere.

## Summary

On AROS, `SDL_CreateRenderer(window, "opengl")` fails when the window was
created hidden, and succeeds on the same machine, in the same process, for a
visible window. The failure sets **no error string**: `SDL_GetError()`, read on
the line after the call, returns an empty string.

Either half is worth fixing on its own. The empty error string is the one that
costs other people time: a program that asks why it was refused is told
nothing.

## Environment

| | |
|---|---|
| AROS | AROS One 1.3, x86_64, ABIv11 (deadwood) |
| SDL3 | 3.4.12 + `SDL3/main/SDL3-3.4.12-aros.diff` from contrib commit `20049962` |
| built as | `libSDL3_static.a`, the static entry point from contrib's `mmakefile.src` |
| machine | QEMU 11.1.1, TCG (no KVM), `-device vmware-svga`, host macOS 27 arm64 |
| GL | `GL_VENDOR` VMware, Inc. / `GL_RENDERER` softpipe / `GL_VERSION` 3.1 Mesa 20.0.8 |

Two local patches were applied on top of contrib's: a `<langinfo.h>` guard,
without which the tree does not compile on this SDK, and an unrelated
text-input change. Neither touches renderer selection. The behaviour below also
occurs with only contrib's patch plus the `langinfo` guard.

## Reproducer

`tests/sdl3-renderer/sdl3-renderer.cpp` in the reporting repository; roughly
60 lines of it matter. For a hidden and a visible window it asks for the
default driver, for `opengl` and for `software`, reading `SDL_GetError()`
immediately after each failed call. It runs hidden first, then visible, then
hidden again, so an order effect cannot hide in the result. It deliberately
does not destroy its windows (see the note at the end).

```
SDL 3.4.12, video driver: aros
render drivers built in:
  0. opengl
  1. software

window   asked for  result
-- pass 1: hidden first, nothing created before --
hidden   (default)  granted    software
hidden   opengl     REFUSED    error text: <none - SDL set no error>
hidden   software   granted    software
-- pass 2: visible --
visible  (default)  granted    opengl
visible  opengl     granted    opengl
visible  software   granted    software
-- pass 3: hidden again, after the visible windows --
hidden   (default)  granted    software
hidden   opengl     REFUSED    error text: <none - SDL set no error>
hidden   software   granted    software
```

Pass 3 repeats pass 1, so the outcome does not depend on what was created
before it within this sequence.

## What is expected

SDL documents `SDL_WINDOW_HIDDEN` as a normal state, and creating a renderer
before showing the window is ordinary usage - it is what OpenLoco does, and how
this was found. On other platforms the same sequence gets an accelerated
renderer.

Minimally: whatever the answer is, `SDL_CreateRenderer()` should set an error
string when it returns NULL.

## What is not claimed

- The performance question is **not** part of this report. On this machine the
  OpenGL renderer is about twenty times slower than the software one, because
  the GL is `softpipe`. That is a property of this environment, not a defect.
- No claim about hardware AROS with a real GL driver; it has not been tested.
- The cause inside the backend has not been located. This is a report of
  observed behaviour and a reproducer, not a patch.

## Related, and deliberately kept separate

While writing the reproducer it also crashed in `AROS_CloseWindowSafely()` when
destroying a hidden window. That was traced to **our own** hidden-window patch
making a latent path reachable, and it is fixed on our side; it is not part of
this report. The relevant detail for the backend, offered as an observation:
`AROS_DestroyWindow()` clears `window->internal` before calling
`AROS_CloseWindowSafely()`, which then reads the window's menu state through
that pointer. Nothing in the stock backend reaches that call with an open
window, so it is latent there - but it is a use-after-clear either way.
