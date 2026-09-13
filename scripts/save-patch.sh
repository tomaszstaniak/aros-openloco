#!/bin/sh
# Turn the current changes in work/OpenLoco into a versioned patch.
#
#   scripts/save-patch.sh <short-name> ["why this patch exists"] [path...]
#
# Writes patches/openloco/NN-<short-name>.diff, where NN keeps the apply order,
# and folds the change into work/'s baseline so `git status` there goes quiet
# again. That is the whole contract: what is in patches/ is saved, what shows
# up in `git -C work/OpenLoco status` is not.
#
# The header matters. A patch without a reason is unreviewable in a month, and
# we cannot tell an upstream-worthy fix from an AROS-only workaround.
set -e
. "$(dirname "$0")/env.sh"

NAME=$1
WHY=$2
shift 2 2>/dev/null || shift $#
# Remaining arguments limit the patch to those paths, so one concern makes one
# patch instead of an afternoon's work landing as a single unreviewable blob.
PATHS="$@"
[ -n "$NAME" ] || { echo "usage: scripts/save-patch.sh <short-name> [\"why\"]" >&2; exit 2; }
case "$NAME" in
    *[!a-zA-Z0-9._-]*) echo "short-name: letters, digits, . _ - only" >&2; exit 2 ;;
esac

[ -d "$WORK_DIR/.git" ] || { echo "no baseline in $WORK_DIR - run scripts/bootstrap.sh" >&2; exit 1; }
if [ -z "$(git -C "$WORK_DIR" status --porcelain)" ]; then
    echo "nothing to save: work/OpenLoco matches upstream + patches"
    exit 0
fi

DEST=$PORT_ROOT/patches/openloco
mkdir -p "$DEST"
NN=$(printf '%02d' $(( $(ls "$DEST"/*.diff 2>/dev/null | wc -l | tr -d ' ') + 1 )))
OUT=$DEST/$NN-$NAME.diff

{
    echo "# $NAME"
    echo "#"
    if [ -n "$WHY" ]; then
        echo "# $WHY"
    else
        echo "# TODO: say why this patch exists before committing it."
    fi
    echo "#"
    echo "# Against OpenLoco $UPSTREAM_COMMIT, applied with -p1 by scripts/bootstrap.sh."
    echo "# Saved $(date '+%Y-%m-%d')."
    echo
} > "$OUT"

# Include new files too, hence the intent-to-add.
if [ -n "$PATHS" ]; then
    git -C "$WORK_DIR" add -N -- $PATHS
    git -C "$WORK_DIR" diff -- $PATHS >> "$OUT"
else
    git -C "$WORK_DIR" add -A -N
    git -C "$WORK_DIR" diff >> "$OUT"
fi

# Fold into the baseline so the next `git status` in work/ is clean and only
# shows what came after this patch.
if [ -n "$PATHS" ]; then
    git -C "$WORK_DIR" add -- $PATHS
else
    git -C "$WORK_DIR" add -A
fi
git -C "$WORK_DIR" -c user.name=save-patch -c user.email=save-patch@local \
    commit -q -m "$NN-$NAME"

echo "wrote $OUT"
[ -n "$WHY" ] || echo "NOTE: fill in the reason line in the header before committing."
