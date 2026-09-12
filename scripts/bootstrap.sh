#!/bin/sh
# Fetch the pinned upstream commit and prepare the working copy.
#
#   scripts/bootstrap.sh          prepare upstream/ and work/
#   scripts/bootstrap.sh --reset  throw work/ away and rebuild it from upstream
#
# upstream/OpenLoco is a clean checkout of UPSTREAM_COMMIT and is treated as
# read-only: never edit it, so we can always tell our changes from the game's.
# work/OpenLoco is the copy we compile and edit, produced by applying every
# patch in patches/openloco/ in filename order. Both are outside our Git.
set -e
. "$(dirname "$0")/env.sh"

RESET=no
[ "$1" = "--reset" ] && RESET=yes

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
# Anything modified here is a mistake: this tree is the reference.
if [ -n "$(git status --porcelain)" ]; then
    echo "upstream/OpenLoco has local modifications - it must stay clean." >&2
    echo "Move them into patches/openloco/ and re-run with --reset." >&2
    exit 1
fi
echo "upstream at $UPSTREAM_COMMIT (clean)"

if [ "$RESET" = yes ]; then
    rm -rf "$WORK_DIR"
fi

if [ ! -d "$WORK_DIR" ]; then
    echo "preparing $WORK_DIR"
    mkdir -p "$(dirname "$WORK_DIR")"
    # A plain copy, without .git: work/ is not a second clone to commit into,
    # it is a scratch tree. Our changes live in patches/openloco/.
    rsync -a --exclude '.git' "$UPSTREAM_DIR/" "$WORK_DIR/"

    applied=0
    for p in "$PORT_ROOT"/patches/openloco/*.diff; do
        [ -e "$p" ] || continue
        echo "  applying $(basename "$p")"
        patch -p1 -d "$WORK_DIR" < "$p"
        applied=$((applied + 1))
    done
    echo "work tree ready ($applied patch(es) applied)"
else
    echo "work tree already present, leaving it alone (--reset to rebuild)"
fi
