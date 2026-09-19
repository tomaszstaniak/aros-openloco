# Patch set for the newer upstream (candidate)

Symlinks to `../openloco/`, minus the patches upstream has since taken. Kept as
a directory of links, not copies, so a fix made once applies to both sets and
the two cannot drift apart.

Excluded here:

| patch | why |
|---|---|
| `20-upstream-4018-drawing-engine-cleanup.diff` | it **is** upstream `6072709d`, contained in `7f8c90cf` - re-applying it would fail as "previously applied" |

Used with the overrides in `scripts/env.sh`:

```sh
export OPENLOCO_UPSTREAM_COMMIT=7f8c90cf…
export OPENLOCO_UPSTREAM_DIR=$PWD/upstream-next/OpenLoco
export OPENLOCO_WORK_DIR=$PWD/work-next/OpenLoco
export OPENLOCO_PATCH_DIR=$PWD/patches/openloco-next
export OPENLOCO_BUILD_ROOT=$PWD/build-next
scripts/bootstrap.sh && scripts/build-openloco.sh abiv11
```

The pinned tree stays the reference while this is evaluated. If the newer
upstream is adopted, this directory becomes the patch set - `20` is deleted,
the links are replaced by the files, and `UPSTREAM_COMMIT` in `env.sh` moves.
