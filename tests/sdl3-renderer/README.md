# sdl3-renderer - minimal reproducer for the AROS renderer refusal

Build: `scripts/build-renderer-test.sh abiv11` (needs `scripts/build-sdl3.sh`
first). Copy the binary next to anything on the guest and run it from a Shell;
it writes the same report to `renderer-probe.txt` in the current directory.

What it does: for a hidden and a visible window, asks `SDL_CreateRenderer` for
the default driver, for `opengl` and for `software`, and reads `SDL_GetError()`
on the line after each failed call. Hidden runs first, then visible, then
hidden again, so an order effect cannot hide inside the result. Then it prints
`GL_VENDOR`, `GL_RENDERER` and `GL_VERSION`.

It **deliberately leaks its windows**: `SDL_DestroyWindow()` on a hidden window
crashes this backend, and destroying windows at all changes the answers. See
backlog item 24, which is what this program exists to document.

Expected output on AROS One 1.3 / SDL3 3.4.12 with this port's patches: a
hidden window is granted `software` and refused `opengl` with an empty error
string; a visible window is granted `opengl`; the GL is `softpipe`.

## sdl3-lifecycle - one window lifecycle per process

`sdl3-lifecycle hidden-bare | hidden-software | visible-opengl | sequence`.
Each run creates one window (and a renderer, where the case has one), destroys
the renderer first and the window second, and prints every step before taking
it, so the last line on screen is the step that crashed. One case per process,
because a crash takes the process with it and a previous case's windows must
not change the next one's conditions; reboot the guest after a crash.

Build it against two SDL3s to tell a contrib defect from one of ours:

    scripts/build-renderer-test.sh abiv11 -fixed
    OPENLOCO_DEPS_ROOT=$PWD/deps-base scripts/build-renderer-test.sh abiv11 -base

`deps-base` is SDL3 3.4.12 + contrib's pinned AROS patch + the `langinfo`
compile guard, nothing else. This is how backlog item 24(c) was attributed.
