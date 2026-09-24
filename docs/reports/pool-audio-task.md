# Task for the VM pool maintainer: where does guest audio go?

Prepared 2026-09-24 by the OpenLoco port. **Not a request to change anything
yet** - a list of what was observed and the checks that would settle it.

## Symptom

No sound is heard from any application in pool guests, not only from OpenLoco.
That points away from a defect confined to one program, but it does not yet
establish the cause, and running headless does not by itself decide whether
sound reaches the host's speakers.

## What the running command lines say (checked 2026-09-24, 19:5x)

The three v11 slots running at the time, read from `ps`:

| slot | `-audiodev` / `-audio` | emulated sound device | display |
|---|---|---|---|
| v11-1 | none | none | `-display cocoa` |
| v11-2 | none | none | `-display cocoa` |
| v11-3 | none | none | `-display cocoa` |

`tools/vm_pool.py` and `tools/vm_pool.local.json` contain no audio settings.
For comparison, the OpenLoco project's retired launcher gave its machine
`-device AC97,audiodev=snd0` with `-audiodev coreaudio,id=snd0` (speakers) or
`-audiodev wav,id=snd0,path=...` (a file). On that machine the game's music was
heard on 2026-09-20.

**On these command lines the guest has no sound card at all.** If that holds
for every slot, silence in every application follows, and nothing inside the
guest - AHI settings, OpenAL, the game - can change it. That is a reading of
the command line; it has not been confirmed from inside a guest (e.g. what AHI
lists as available hardware).

## Checks, in order

1. Confirm on every slot, v1 included, the actual QEMU arguments for audio:
   the emulated device, the host backend, and where it outputs.
2. Decide which mode the pool intends: sound to the host device
   (`coreaudio`), to a WAV file per run, or none. Record it in
   `documentation/vm-pool.md` either way - "no sound by design" is a valid
   answer, but it should be written down.
3. If audio is enabled: compare a known audio application with OpenLoco on the
   same slot, same boot. Both silent points further along the chain; one
   silent points at that program.
4. If a WAV recording comes out right and the speakers stay silent, the problem
   is in the rest of the playback path (host backend, cocoa, output device),
   not in the guest.

## What this does not change

- The earlier listen on 2026-09-20 confirmed music for **that build and that
  machine configuration**. Silence in the current pool neither confirms live
  sound there nor cancels that result.
- The game's audio code is not being changed on the strength of a symptom that
  every application shares.
