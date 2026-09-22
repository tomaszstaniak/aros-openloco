# Upstream candidates - reviewed, none sent

Reviewed 2026-09-23. **Nothing has been sent anywhere.** Preparing a change and
offering it are separate decisions; this file records the first.

Three projects could receive something from this port, and they want different
things.

## OpenLoco (the game)

| patch | what it is | verdict |
|---|---|---|
| `21-aros-orderly-sdl-shutdown` | adds `Ui::disposeWindow()`, calls it after the drawing engine is disposed, and calls `SDL_Quit()` where upstream has it commented out | **candidate** |
| `23-aros-version-identifier` | lets the build supply `OPENLOCO_VERSION_TAG` / `BRANCH` / `COMMIT_SHA1_SHORT`; CMake reads git only when they are absent | **candidate** |
| 01-17 | AROS paths, GCC 10 workarounds, socket and OpenAL shims, FAT32 overwrite | **no** - platform-specific to a platform upstream does not build for |
| 20 | a verbatim backport of upstream's own `6072709d` | **no** - already upstream; it exists here only because our pin is older |

**Patch 21.** Upstream's `exitCleanly()` leaves the game window alive and has
`SDL_Quit()` commented out. On AROS that left a stale Intuition window and five
unfreed signal bits; with the patch, one. The argument for it is not "AROS
needs it" - it is that shutting down the library you initialised is right
anywhere, and the ownership question was checked before writing the patch: the
only static SDL holders are raw pointers, and the drawing engine is disposed
explicitly first, so no static destructor touches SDL after `SDL_Quit()`.

What a maintainer would fairly ask, and we cannot answer: whether the commented
`SDL_Quit()` was commented out **for a reason** on Windows or macOS. That
question belongs in the offer, not in an answer we invent. Tested on AROS only.

**Patch 23.** Small, opt-in, no behaviour change when the build passes nothing.
Useful to anyone building OpenLoco from a generated or exported tree, where the
git hash names nothing. It is also the smallest thing here, which makes it a
reasonable first contact.

**Not a candidate, but worth mentioning if we ever open an issue:** the
`FileStream` read failure message names the wrong cause. It reports a read
error where the real one is a failure to open. That is a one-line fix, but we
have not written it as a patch.

## SDL3 on AROS (`aros-development-team/contrib`)

| what | verdict |
|---|---|
| hidden-window framebuffer, both parts | **candidate** |
| the silent `opengl` refusal | **report, not a patch** - see `sdl3-aros-hidden-window-opengl.md` |
| `langinfo` guard | **candidate**, trivially |
| text input | needs a second look before offering |

**The hidden-window patch.** SDL allows `SDL_GetWindowSurface()` on a hidden
window and applications rely on it; without this the AROS backend fails with
"No system window" and OpenLoco cannot start at all. The patch opens the
Intuition window on demand.

It now has a second part, and **the second part exists because the first one
caused a crash**: with a system window attached to a still-hidden SDL window,
`AROS_DestroyWindow()` walked into contrib's own use-after-clear of
`window->internal`. That we fixed our own regression does not reduce the value
of the feature - but an offer must carry both parts and say plainly why the
second exists. A maintainer may well prefer to fix the destroy order in the
backend regardless, since it is wrong on its own terms.

**The `langinfo` guard** is a compile fix: the ABIv11 SDK has no
`<langinfo.h>`, and the tree does not build without the guard. Nothing to argue
about; it would just need the right conditional for their tree rather than
ours.

**Text input** works and is in daily use here, but it was written against one
keymap and one ABI and has had no review against the backend's own event model.
Not offered until that is done.

## AROS itself

Nothing. No AROS source has been touched by this port. Two findings belong
there and neither is ready:

- FAT32 writes: overwriting an existing file is unreliable and volumes have
  been damaged (backlog item 18). We work around it in the game; the cause is
  in the handler and is not isolated.
- GL is `softpipe` under TCG. Not a defect - an observation about the
  environment.
