#!/bin/sh
# Fetch the pinned upstream commit and prepare the working copy.
#
#   scripts/bootstrap.sh           prepare upstream/ and work/, report work/ state
#   scripts/bootstrap.sh --reset   rebuild work/ from upstream — REFUSES if work/
#                                  holds changes not yet saved as a patch
#   scripts/bootstrap.sh --reset --force
#                                  rebuild anyway, throwing those changes away
#
# upstream/OpenLoco is a clean checkout of UPSTREAM_COMMIT, treated as
# read-only, so we can always tell our changes from the game's.
#
# work/OpenLoco is the copy we compile and edit. It gets its own private Git
# repo whose first commit is upstream + every patch in patches/openloco/. That
# baseline is not our port's history — it exists so that `git status` in work/
# answers one question exactly: what have I changed and not saved as a patch
# yet? Without it a --reset silently destroys an afternoon of edits, because
# nothing else can tell an edit apart from the pristine tree.
#
# Use scripts/save-patch.sh to turn those changes into patches/openloco/.
set -e
. "$(dirname "$0")/env.sh"

RESET=no
FORCE=no
for arg in "$@"; do
    case "$arg" in
        --reset) RESET=yes ;;
        --force) FORCE=yes ;;
        *) echo "unknown option '$arg'" >&2; exit 2 ;;
    esac
done

# --- upstream: clean checkout of the pinned commit ------------------------
if [ ! -d "$UPSTREAM_DIR/.git" ]; then
    echo "cloning upstream into $UPSTREAM_DIR"
    mkdir -p "$(dirname "$UPSTREAM_DIR")"
    git clone "$UPSTREAM_REPO" "$UPSTREAM_DIR"
fi

cd "$UPSTREAM_DIR"
if [ "$(git rev-parse HEAD)" != "$UPSTREAM_COMMIT" ]; then
    git fetch origin
    git checkout --detach "$UPSTREAM_COMMIT"
fi
if [ -n "$(git status --porcelain)" ]; then
    echo "upstream/OpenLoco has local modifications - it must stay clean." >&2
    echo "Move them into $PATCH_DIR and re-run with --reset." >&2
    exit 1
fi
echo "upstream at $UPSTREAM_COMMIT (clean)"

# --- work: what is in there that we would lose? ---------------------------
work_dirty() {
    [ -d "$WORK_DIR/.git" ] || return 1
    [ -n "$(git -C "$WORK_DIR" status --porcelain)" ]
}

report_dirty() {
    echo
    echo "work/OpenLoco has changes that are NOT saved as a patch:"
    git -C "$WORK_DIR" status --short | sed 's/^/  /'
    echo
    echo "Save them first:   scripts/save-patch.sh <short-name>"
    echo "Or inspect them:   git -C work/OpenLoco diff"
}

if [ -d "$WORK_DIR" ] && [ ! -d "$WORK_DIR/.git" ]; then
    # A tree from before this mechanism existed. We cannot tell edits from the
    # pristine copy, so we must not touch it.
    echo "work/OpenLoco exists but has no baseline repo - cannot tell whether" >&2
    echo "it holds unsaved changes. Move it aside by hand, then re-run." >&2
    exit 1
fi

if [ "$RESET" = yes ] && work_dirty; then
    if [ "$FORCE" != yes ]; then
        report_dirty
        echo "Refusing to reset. Add --force to discard the changes above."
        exit 1
    fi
    echo "--force given: discarding the changes in work/OpenLoco"
fi

if [ "$RESET" = yes ]; then
    rm -rf "$WORK_DIR"
fi

# --- work: build it from upstream + patches -------------------------------
if [ ! -d "$WORK_DIR" ]; then
    echo "preparing $WORK_DIR"
    mkdir -p "$(dirname "$WORK_DIR")"
    rsync -a --exclude '.git' "$UPSTREAM_DIR/" "$WORK_DIR/"

    applied=0
    for p in "$PATCH_DIR"/*.diff; do
        [ -e "$p" ] || continue
        echo "  applying $(basename "$p")"
        patch -p1 -d "$WORK_DIR" < "$p"
        applied=$((applied + 1))
    done

    git -C "$WORK_DIR" init -q -b baseline
    git -C "$WORK_DIR" add -A
    git -C "$WORK_DIR" -c user.name=bootstrap -c user.email=bootstrap@local \
        commit -q -m "baseline: $UPSTREAM_COMMIT + $applied patch(es) from $(basename "$PATCH_DIR")"
    echo "work tree ready ($applied patch(es) applied, baseline recorded)"
else
    if work_dirty; then
        report_dirty
        echo "Leaving work/OpenLoco alone."
    else
        echo "work tree present and matches upstream + patches"
    fi
fi
