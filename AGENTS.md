# aros-openloco - project rules

The shared rules are in `../AGENTS.md` and apply here in full. Below is only
what is specific to this port.

## ABI choice - in line with the shared rule

The shared rule (the testbench's shared rules, §Scope decisions, clarified
2026-09-15): **ABI priority is chosen per project**, and picking ABIv11 first is
normal configuration, not an exception. An earlier version of this section
described it as a deviation, which matched the rule's earlier wording
("development tracks mainline"); that wording has since changed.

**This port: ABIv11 (AROS One) first, mainline v1 second.** User instruction of
2026-09-12. The practical reason: ABIv11 is the one whose SDK carries OpenAL and
iconv and a working toolchain for this game, and it is where SDL3 and the game
itself were run. Mainline v1 **is not dropped** - it stays the second target and
every compile probe runs on both. Mainline has never been run, though: all
runtime results are ABIv11 only and are labelled as such.

A result from one ABI is not a result from the other - these systems have
different libstdc++, different SDKs and different posixc contents, and they once
differed by 300 files. Every report must say which ABI it came from.

## Where things live

- `upstream/OpenLoco` - **never edit.** If `git status` there is not clean, that
  is a mistake, not a state of work. `scripts/bootstrap.sh` checks it.
- `work/OpenLoco` - this is where you edit. It has a private Git repository, but
  that is **not the port's history**: its only job is to answer what has been
  changed and not yet saved. Do not commit there by hand.
- Every change to the game's code that is meant to stay becomes a patch:
  `scripts/save-patch.sh <name> "why"`. A change living only in `work/` is not
  saved - but it is not silently deleted either: `bootstrap.sh --reset` refuses
  until `git -C work/OpenLoco status` is clean.
- Dependency patches (`patches/dependencies/`) likewise: the header must carry
  the reason and the scope, because in six months nobody will reconstruct why
  fmt was touched.

## Compile probes

Flags mirror upstream's `cmake/OpenLocoCommon.cmake`. Any divergence must be
explicit and commented in the script. A probe with different flags invents
errors the real build never sees - that happened with `-fno-char8_t` and
inflated the "fixes to make" count by 15 files.

A number like "366/394" is a statement about translation units. It is not a
percentage of the port's readiness, not evidence of linking, and not evidence of
running. Describe it that way.

## Order of evidence in this port

1. sources exist in contrib ->
2. the library builds ->
3. it is installed in a specific SDK ->
4. the program links ->
5. it runs on the named machine.

Do not skip degrees when describing something. SDL3 on ABIv11 is at degree 5
today, but as a static build alongside the AROS build system - not as contrib's
`sdl3.library`, and that has to be said every time.

## Traps that have already cost an afternoon

Full list: `../docs/platform/porting-notes.md` - **read it before the first
build**, not after. Three of them hit this port directly:

- **Do not strip the binary fully.** `x86_64-aros-strip` without flags produces
  a file that AROS One loads without `.text` relocations and that dies in the
  first `OpenLibrary()` - it looks like a bug in the program. Use
  `--strip-unneeded --remove-section .comment`.
- **`libpng.a` and `libz.a` in the SDK are stubs** into `png.library` and
  `z1.library`. Link `-lpng_nostdio -lz.static` (in that order - png calls into
  zlib); both SDKs have them. The reason is **independence from the library
  version on the user's machine**, not its absence: on our AROS One 1.3 both
  libraries are present. Checked and run here; details in backlog §9.
- **Mouse coordinates from SDL2 events returned (0,0) on AROS.** For SDL3 this
  is only partly checked: in the running game an injected click hit a menu globe
  and started a scenario. Dragging, the right button and a comparison against
  `SDL_GetMouseState` are still unchecked - backlog §10.

## Running on the machines

The testbench is shared - rules in `../docs/platform/testbench.md`. ABIv11 is
machine `one`. Test programs write their result to a file (`PROGDIR:*.log`)
rather than the console, because the Shell may contain another session's output.
