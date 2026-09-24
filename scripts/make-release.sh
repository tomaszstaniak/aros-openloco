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
# With OPENLOCO_ARCHIVE_NAME set it also packs the drawer into that .lha and
# writes its SHA-256 next to it. It uploads nothing; publishing is separate.
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
# A release binary must come from a configure in a clean directory - see the
# stamp logic in build-openloco.sh and why dates were not enough.
CONFIGURE=$(awk '/^configure:/{print $2}' "$ARCHIVE/BUILD-INFO.txt")
[ "$CONFIGURE" = fresh ] || {
    echo "refusing: that build was not configured in a clean directory (configure: ${CONFIGURE:-not recorded})." >&2
    echo "Build it with OPENLOCO_FRESH_CONFIGURE=1 scripts/build-openloco.sh $ABI" >&2
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
# Provenance for the user, with this build machine's home directory replaced
# by ~ - the paths say which tree, the user name adds nothing.
for f in BUILD-INFO.txt PATCHES.txt BUILT-WITH.txt DEPENDENCIES.txt; do
    sed "s|$HOME|~|g" "$ARCHIVE/$f" > "$OUT/$f"
done
# Licences of everything the binary contains or ships with.
mkdir -p "$OUT/Licenses"
cp "$PORT_ROOT"/licenses/*.txt "$OUT/Licenses/"
cp "$PORT_ROOT/THIRD-PARTY-NOTICES.md" "$OUT/Licenses/"
cp "$PORT_ROOT/LICENSE" "$OUT/Licenses/aros-openloco-LICENSE.txt"
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
; Run this from inside the OpenLoco drawer:
;     cd <drawer>
;     execute Run-OpenLoco
;
; Why it exists: the default Shell stack (40960 bytes on a stock AROS One 1.3)
; is too small, and OpenLoco then dies inside drawImage with
; "Stack extends out of range" before it draws its first screen.
;
; The check below is not decoration. Run from somewhere else, a bare "OpenLoco"
; matches this DRAWER rather than the program inside it, and the Shell simply
; changes directory and returns - no game, no error. Verified on a pool machine
; 2026-09-23.
if not exists openloco.yml
    echo "Run-OpenLoco must be started from inside the OpenLoco drawer."
    echo "Do:  cd <the drawer>   then   execute Run-OpenLoco"
    quit 10
endif
; openloco.yml only says this looks like the drawer. Check the things the game
; itself cannot start without, and name the one that is missing.
; File or drawer is told apart by cd, not by "exists": on AROS "exists name/"
; is true for a plain file too (tested 2026-09-24), and list returns OK whether
; or not anything matched. cd into a file fails; cd into a drawer succeeds and
; is undone at once. failat keeps a failed cd from ending the script.
failat 21
if not exists OpenLoco
    echo "The program OpenLoco is missing from this drawer."
    echo "Copy the whole OpenLoco drawer again from the archive."
    quit 10
endif
cd OpenLoco >NIL:
if not error
    cd /
    echo "OpenLoco in this drawer is a drawer, not the program."
    echo "Copy the whole OpenLoco drawer again from the archive."
    quit 10
endif
if not exists data/language/en-GB.yml
    echo "data/language/en-GB.yml is missing - the game's own text files."
    echo "Without data/ the game stops with: OpenLoco data path could not be found!"
    echo "Copy the whole OpenLoco drawer again from the archive."
    quit 10
endif
cd data/objects >NIL:
if error
    echo "The drawer data/objects is missing - the objects the game ships with."
    echo "Copy the whole OpenLoco drawer again from the archive."
    quit 10
endif
cd //
stack 1048576
OpenLoco
LAUNCH

echo "$SHA  OpenLoco" > "$OUT/SHA256"

# The archive for publication: an LhA of the drawer, as AROS users expect, plus
# a SHA-256 of that archive. lha stores the drawer name, so it extracts as
# OpenLoco/. Its name carries the ABI; the version is in BUILD-INFO.txt inside.
if [ -n "${OPENLOCO_ARCHIVE_NAME:-}" ]; then
    # Homebrew's lha is Lhasa, which only extracts. Use jca02266's LHa for
    # UNIX - the one AROS itself builds (tools/lha in the AROS sources).
    : "${LHA_WRITER:?set LHA_WRITER to a create-capable lha (jca02266/lha)}"
    "$LHA_WRITER" --help 2>&1 | grep -q 'a   Add' ||
        { echo "$LHA_WRITER cannot create archives" >&2; exit 1; }
    LHA=$PORT_ROOT/release/$ABI/$OPENLOCO_ARCHIVE_NAME
    rm -f "$LHA" "$LHA.sha256"
    (cd "$PORT_ROOT/release/$ABI" && "$LHA_WRITER" -aq "$OPENLOCO_ARCHIVE_NAME" OpenLoco)
    (cd "$PORT_ROOT/release/$ABI" && shasum -a 256 "$OPENLOCO_ARCHIVE_NAME" > "$OPENLOCO_ARCHIVE_NAME.sha256")
    echo "archive: $LHA"
    cat "$LHA.sha256"
fi
echo "prepared $OUT"
echo "  version: $VERSION"
echo "  sha256:  $SHA"
ls -l "$OUT"
