#!/bin/sh
# Assemble a directory a user can copy onto an AROS machine and run.
#
#   scripts/make-release.sh [abi]          default abi: abiv11
#
# It takes the binary that was last built for that ABI, refuses if the tree it
# came from was dirty, and puts it next to the files a first run needs: a
# config pointing at the game's assets, and a README saying what the program
# expects and what is known to be wrong with it.
#
# It deliberately does NOT produce an archive to upload anywhere. Publishing is
# a separate decision and is not taken here.
set -e
. "$(dirname "$0")/env.sh"

ABI=${1:-abiv11}
BUILD=$(abi_build "$ABI")/openloco
BIN=$BUILD/OpenLoco
[ -f "$BIN" ] || { echo "no $BIN - run scripts/build-openloco.sh $ABI" >&2; exit 1; }

SHA=$(shasum -a 256 "$BIN" | cut -d' ' -f1)
ARCHIVE=${AROS_TESTBENCH:-$HOME/Work/AROS}/loco-variants/builds/$SHA
[ -d "$ARCHIVE" ] || { echo "this binary is not archived - build it with build-openloco.sh" >&2; exit 1; }

DIRTY=$(awk '/^work dirty/{print $3}' "$ARCHIVE/BUILD-INFO.txt")
[ "$DIRTY" = "0" ] || {
    echo "refusing: that build came from a work tree with $DIRTY changed file(s)." >&2
    echo "A build for other people must be reproducible from the patch set alone." >&2
    exit 1; }
VERSION=$(awk -F': *' '/^version/{print $2}' "$ARCHIVE/BUILD-INFO.txt")

OUT=$PORT_ROOT/release/$ABI/OpenLoco
rm -rf "$OUT"; mkdir -p "$OUT"
cp "$BIN" "$OUT/OpenLoco"
# The game's own data directory - language files and the objects it ships -
# lives next to the binary. Leaving it out cost a full pool run: the game
# starts, finds no data directory and throws
# "OpenLoco data path could not be found!" from getDataDirectory().
[ -d "$BUILD/data" ] || { echo "no $BUILD/data - the build is incomplete" >&2; exit 1; }
cp -R "$BUILD/data" "$OUT/data"
# The game looks for a user objects drawer next to itself and warns when it is
# missing. Empty, and created here so a fresh install does not start with a
# warning; the game fills it if the player adds custom objects.
mkdir -p "$OUT/objects"
cp "$ARCHIVE/BUILD-INFO.txt" "$ARCHIVE/PATCHES.txt" "$ARCHIVE/BUILT-WITH.txt" \
   "$ARCHIVE/DEPENDENCIES.txt" "$OUT/"
sed -e "s|@VERSION@|$VERSION|" -e "s|@SHA@|$SHA|" \
    "$PORT_ROOT/docs/user-readme.md" > "$OUT/README.md"
cat > "$OUT/openloco.yml" <<'EOF'
# Where your own copy of Chris Sawyer's Locomotion is installed.
# Change this line if your assets are somewhere else; everything else is
# written by the game itself on first exit.
loco_install_path: Locodata:Locomotion
display:
  mode: window
  window_resolution:
    width: 640
    height: 480
EOF

# A launcher, because the default Shell stack is not enough. On a pool machine
# with AROS One 1.3 it is 40960 bytes, and the game dies inside
# SoftwareDrawingContext::drawImage with "Stack extends out of range" before it
# ever reaches the title screen. Backlog item 26.
cat > "$OUT/Run-OpenLoco" <<'LAUNCH'
.key
; Run this with:  execute Run-OpenLoco
; The default Shell stack (40 KB on AROS One 1.3) is too small for OpenLoco:
; it crashes in drawImage with "Stack extends out of range".
stack 1048576
OpenLoco
LAUNCH

echo "$SHA  OpenLoco" > "$OUT/SHA256"
echo "prepared $OUT"
echo "  version: $VERSION"
echo "  sha256:  $SHA"
ls -l "$OUT"
