#!/usr/bin/env bash
# End-to-end test of the image-transform-tools scripts on synthetic images.
# Everything is built under a fresh mktemp directory; no photograph is stored
# in this repository. Deletes nothing; the OS temp cleaner owns the directory.
# The conversion needs macOS with libtiff and exiftool; anywhere else the
# test checks that preflight says so and stops there.
# Exit 0 when every assertion holds.
set -eu
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
S="$HERE/../skills/image-transform-tools/scripts"
T="$(mktemp -d "${TMPDIR:-/tmp}/ttph-test.XXXXXX")"
T="$(cd "$T" && pwd -P)"
fails=0
pass() { printf 'ok    %s\n' "$1"; }
bad()  { printf 'FAIL  %s\n' "$1"; fails=$((fails + 1)); }
is()   { if [ "$2" = "$3" ]; then pass "$1"; else bad "$1: expected '$3', got '$2'"; fi; }
has()  { if printf '%s' "$2" | grep -qF -- "$3"; then pass "$1"; else bad "$1: '$3' not found"; fi; }
hasnt(){ if printf '%s' "$2" | grep -qF -- "$3"; then bad "$1: '$3' should not appear"; else pass "$1"; fi; }
code() { set +e; "$@" >/dev/null 2>&1; c=$?; set -e; printf '%s' "$c"; }
exists() { if [ -e "$2" ]; then pass "$1"; else bad "$1: $2 missing"; fi; }
absent() { if [ -e "$2" ]; then bad "$1: $2 should not exist"; else pass "$1"; fi; }
sum()  { cksum < "$1" | tr -d ' '; }
finish() { echo; if [ "$fails" -gt 0 ]; then echo "$fails failure(s)"; exit 1; else echo "all passed"; fi; }

# --- things that hold on every operating system
is "preflight rejects an unknown recipe" "$(code bash "$S/preflight.sh" --recipe nope)" 2
is "heic-to-tiff with no arguments is a usage error" "$(code bash "$S/heic-to-tiff.sh")" 2
is "list with no arguments is a usage error" "$(code bash "$S/list.sh")" 2
. "$S/lib/common.sh"
is "selection 1-3,5 expands" "$(expand_selection "1-3,5" 6 | tr '\n' ' ')" "1 2 3 5 "
is "selection with spaces expands" "$(expand_selection "2 4" 6 | tr '\n' ' ')" "2 4 "
is "selection out of range is refused" "$(code expand_selection "7" 6)" 2
is "selection that is not a number is refused" "$(code expand_selection "abc" 6)" 2
is "reversed range is refused" "$(code expand_selection "5-2" 6)" 2
mkdir -p "$T/u"; : > "$T/u/r.md"
is "unique_path steps past an existing file" "$(unique_path "$T/u/r" md)" "$T/u/r-2.md"
echo keep > "$T/u/keep.txt"
is "write_new refuses an existing file" "$(printf 'x' | code write_new "$T/u/keep.txt")" 1
is "write_new left the file alone" "$(cat "$T/u/keep.txt")" "keep"

pre="$(code bash "$S/preflight.sh")"
if [ "$(uname -s)" != Darwin ]; then
    is "preflight reports an unsupported operating system" "$pre" 4
    is "heic-to-tiff stops with the same code" "$(mkdir -p "$T/e" && code bash "$S/heic-to-tiff.sh" "$T/e" "$T/e-out")" 4
    echo "skip  conversion tests need macOS"
    finish
fi
if [ "$pre" != 0 ]; then
    is "preflight reports missing tools" "$pre" 3
    has "preflight names an install command" "$(bash "$S/preflight.sh" 2>&1 || true)" "brew install"
    echo "skip  conversion tests need libtiff and exiftool (brew install libtiff exiftool)"
    finish
fi
pass "preflight is ready"

# --- synthetic sources: a 64x48 BMP written byte by byte, encoded to HEIC by sips
bmp="$T/fixture.bmp"
{
    printf 'BM\066\044\000\000\000\000\000\000\066\000\000\000'
    printf '\050\000\000\000\100\000\000\000\060\000\000\000\001\000\030\000'
    printf '\000\000\000\000\000\044\000\000\023\013\000\000\023\013\000\000'
    printf '\000\000\000\000\000\000\000\000'
    awk 'BEGIN { for (y = 0; y < 48; y++) for (x = 0; x < 64; x++)
        printf "%c%c%c", 48 + (x % 60), 48 + (y % 60), 48 + ((x + y) % 60) }'
} > "$bmp"
is "fixture is a 9270-byte bitmap" "$(wc -c < "$bmp" | tr -d ' ')" 9270

SRC="$T/src dir"; DST="$T/out dir"       # spaces on purpose
mkdir -p "$SRC"
for n in "IMG_0001.HEIC" "IMG_0002.heic" "with space.HEIC" "IMG_0004.HEIC"; do
    sips -s format heic "$bmp" --out "$SRC/$n" >/dev/null 2>&1 || true
done
exists "sips encoded a HEIC fixture" "$SRC/IMG_0001.HEIC"
[ -e "$SRC/IMG_0001.HEIC" ] || finish
exiftool -q -q -overwrite_original -Make=TestCam -Model=Synthetic \
    -DateTimeOriginal="2026:01:02 03:04:05" -FNumber=1.78 "$SRC/IMG_0001.HEIC"
: > "$SRC/._IMG_0001.HEIC"                 # a dot file must be ignored
echo "not an image" > "$SRC/notes.txt"

before="$(cd "$SRC" && for f in *; do printf '%s %s\n' "$f" "$(sum "$f")"; done)"

# --- list
lst="$(bash "$S/list.sh" "$SRC")"
is "list shows four sources and a header" "$(printf '%s\n' "$lst" | wc -l | tr -d ' ')" 5
has "list numbers the first file" "$lst" "1	IMG_0001.HEIC"
has "list reports pixels" "$lst" "64x48"
hasnt "list ignores dot files" "$lst" "._IMG"
is "list of a folder with no sources exits 1" "$(mkdir -p "$T/none" && code bash "$S/list.sh" "$T/none")" 1

# --- the checkbox window, built and read back without being shown
is "pick returns the ticked numbers" "$(IMAGE_TRANSFORM_PICK_TEST=2,4 bash "$S/pick.sh" "$SRC")" "2,4"
is "pick on a folder with no sources exits 1" "$(IMAGE_TRANSFORM_PICK_TEST=1 code bash "$S/pick.sh" "$T/none")" 1
ORD="$T/order"; mkdir -p "$ORD"
cp "$SRC/IMG_0001.HEIC" "$ORD/b-second.HEIC"
cp "$SRC/IMG_0001.HEIC" "$ORD/A-first.heic"
cp "$SRC/IMG_0001.HEIC" "$ORD/C-third.HEIC"
is "sources are sorted by name whatever the letter case" "$(bash "$S/list.sh" "$ORD" | awk -F'\t' 'NR>1{printf "%s ", $2}')" "A-first.heic b-second.HEIC C-third.HEIC "

# --- dry run writes nothing
dry="$(bash "$S/heic-to-tiff.sh" "$SRC" "$DST" --dry-run)"
has "dry run says what it would do" "$dry" "would convert  IMG_0001.HEIC -> IMG_0001.tif"
has "dry run says nothing was written" "$dry" "Nothing was written"
absent "dry run does not create the destination" "$DST"

# --- a file that already has the output's name is left alone
mkdir -p "$DST"
echo "mine" > "$DST/IMG_0004.tif"

# --- selection
out="$(bash "$S/heic-to-tiff.sh" "$SRC" "$DST" --select "2")"
exists "selected file converted" "$DST/IMG_0002.tif"
absent "unselected file not converted" "$DST/IMG_0001.tif"
has "selection run reports one verified" "$out" "1 verified"
is "selection out of range is a usage error" "$(code bash "$S/heic-to-tiff.sh" "$SRC" "$DST" --select "9")" 2

# --- batch, with a report
sum2="$(sum "$DST/IMG_0002.tif")"
out="$(bash "$S/heic-to-tiff.sh" "$SRC" "$DST" --report md)"
exists "batch converts the first file" "$DST/IMG_0001.tif"
exists "batch handles a name with a space" "$DST/with space.tif"
has "batch verifies two new files" "$out" "2 verified"
has "batch reports two that already existed" "$out" "2 already existed"
has "batch reports no failures" "$out" "0 failed"
is "an earlier output is not rewritten" "$(sum "$DST/IMG_0002.tif")" "$sum2"
is "a file that had the output's name is untouched" "$(cat "$DST/IMG_0004.tif")" "mine"

info="$(tiffinfo "$DST/IMG_0001.tif" 2>/dev/null)"
has "output is LZW" "$info" "Compression Scheme: LZW"
has "output is 8 bits per sample" "$info" "Bits/Sample: 8"
has "output is 64 wide" "$info" "Image Width: 64"
meta="$(exiftool -s -n -Make -Model -DateTimeOriginal -FNumber "$DST/IMG_0001.tif")"
has "metadata: make carried over" "$meta" "TestCam"
has "metadata: capture date carried over" "$meta" "2026:01:02 03:04:05"
has "metadata: f-number not rounded" "$meta" "1.78"

rep="$(ls "$DST"/image-transform-report-*.md 2>/dev/null | head -1)"
exists "report written" "${rep:-$DST/no-report}"
if [ -n "$rep" ]; then
    rt="$(cat "$rep")"
    has "report has a row for a verified file" "$rt" "| IMG_0001.HEIC | IMG_0001.tif | verified |"
    has "report has a row for a skipped file" "$rt" "skipped-exists"
    has "report shows pixels, bits and profile" "$rt" "| 64x48 | 8 |"
    has "report names the source folder" "$rt" "$SRC"
fi

# --- sources untouched, nothing left behind
after="$(cd "$SRC" && for f in *; do printf '%s %s\n' "$f" "$(sum "$f")"; done)"
is "source folder is byte for byte as it was" "$after" "$before"
is "no temp files left in the destination" "$(ls -A "$DST" | grep -c '^\.image-transform' || true)" 0
is "source folder holds no dot files but the one planted" "$(ls -A "$SRC" | grep -c '^\.' || true)" 1

# --- running again changes nothing; a second report does not replace the first
s1="$(sum "$DST/IMG_0001.tif")"
out="$(bash "$S/heic-to-tiff.sh" "$SRC" "$DST" --report csv)"
has "second run converts nothing" "$out" "0 verified"
has "second run finds all four present" "$out" "4 already existed"
is "second run leaves outputs as they were" "$(sum "$DST/IMG_0001.tif")" "$s1"
exists "csv report written beside the first" "$(ls "$DST"/image-transform-report-*.csv 2>/dev/null | head -1)"
exists "first report still there" "$rep"

# --- uncompressed on request, unverified on request, source and destination the same folder
SAME="$T/same"; mkdir -p "$SAME"
cp "$SRC/IMG_0001.HEIC" "$SAME/a.HEIC"
out="$(bash "$S/heic-to-tiff.sh" "$SAME" "$SAME" --compression none --no-verify)"
has "no-verify run says converted without verification" "$out" "1 converted without verification"
has "compression none is honoured" "$(tiffinfo "$SAME/a.tif" 2>/dev/null)" "Compression Scheme: None"
exists "source still beside its output" "$SAME/a.HEIC"

# --- two sources that would become the same file: neither is converted
COL="$T/col"; mkdir -p "$COL"
cp "$SRC/IMG_0001.HEIC" "$COL/shot.heic"
cp "$SRC/IMG_0001.HEIC" "$COL/shot.heif"
cp "$SRC/IMG_0001.HEIC" "$COL/other.heic"
has "list marks a collision" "$(bash "$S/list.sh" "$COL")" "collision"
out="$(bash "$S/heic-to-tiff.sh" "$COL" "$COL/out")"
has "collision reported" "$out" "2 in a name collision"
absent "colliding sources produce no output" "$COL/out/shot.tif"
exists "the other source is still converted" "$COL/out/other.tif"

# --- subfolders: left alone unless asked for, mirrored in the destination when asked
REC="$T/rec"; mkdir -p "$REC/sub one/deeper" "$REC/.hidden"
cp "$SRC/IMG_0001.HEIC" "$REC/top.HEIC"
cp "$SRC/IMG_0001.HEIC" "$REC/sub one/top.HEIC"          # same name, different folder: no clash
cp "$SRC/IMG_0001.HEIC" "$REC/sub one/deeper/inner.heic"
cp "$SRC/IMG_0001.HEIC" "$REC/.hidden/secret.HEIC"
is "without --recursive only the top level is listed" "$(bash "$S/list.sh" "$REC" | wc -l | tr -d ' ')" 2
lst="$(bash "$S/list.sh" "$REC" --recursive)"
is "with --recursive the subfolders are listed" "$(printf '%s\n' "$lst" | wc -l | tr -d ' ')" 4
has "recursive names are relative paths" "$lst" "sub one/deeper/inner.heic"
hasnt "a dot folder is not entered" "$lst" "secret"
hasnt "the same name in two folders is not a collision" "$lst" "collision"
is "pick numbers match the recursive list" "$(IMAGE_TRANSFORM_PICK_TEST=2 bash "$S/pick.sh" "$REC" --recursive)" "2"
out="$(bash "$S/heic-to-tiff.sh" "$REC" "$T/rec-out")"
has "a plain run converts the top level only" "$out" "1 source files"
absent "a plain run does not enter subfolders" "$T/rec-out/sub one"
out="$(bash "$S/heic-to-tiff.sh" "$REC" "$T/rec-out" --recursive --report md)"
exists "recursive output keeps its subfolder" "$T/rec-out/sub one/top.tif"
exists "recursive output keeps a deeper subfolder" "$T/rec-out/sub one/deeper/inner.tif"
absent "a dot folder produces nothing" "$T/rec-out/.hidden"
has "recursive run verifies the two new files" "$out" "2 verified"
has "recursive run leaves the earlier output alone" "$out" "1 already existed"
has "the report names files by relative path" "$(cat "$T"/rec-out/image-transform-report-*.md)" "| sub one/deeper/inner.heic | sub one/deeper/inner.tif | verified |"

# --- progress: counters on each line, a status file, and status.sh
PRG="$T/prg"; mkdir -p "$PRG"
cp "$SRC/IMG_0001.HEIC" "$PRG/one.HEIC"; cp "$SRC/IMG_0001.HEIC" "$PRG/two.HEIC"
out="$(bash "$S/heic-to-tiff.sh" "$PRG" "$PRG/out" --progress-file auto)"
has "each line carries a counter" "$out" "[2/2] verified"
has "the summary says how long it took" "$out" "Took "
pf="$(printf '%s\n' "$out" | sed -n 's/^progress: //p')"
exists "auto progress file is created and named first" "${pf:-$PRG/no-progress-file}"
has "progress file ends in state done" "$(cat "$pf")" "state=done"
has "progress file counts the files" "$(cat "$pf")" "verified=2"
st="$(bash "$S/status.sh" "$pf")"
has "status reports a finished run" "$st" "finished: 2 of 2 done"
is "status exits 0 when finished" "$(code bash "$S/status.sh" "$pf")" 0
echo "mine" > "$PRG/taken.txt"
is "a progress path that exists is refused" "$(code bash "$S/heic-to-tiff.sh" "$PRG" "$PRG/out" --progress-file "$PRG/taken.txt")" 2
is "the file at that path is untouched" "$(cat "$PRG/taken.txt")" "mine"
bash "$S/heic-to-tiff.sh" "$PRG" "$PRG/out" --progress-file "$PRG/mine.status" >/dev/null
has "a named progress file is written" "$(cat "$PRG/mine.status")" "exists=2"
J="$S/lib/progress-window.js"
has "the progress window reads a finished run" "$(osascript -l JavaScript "$J" "$pf" "Converting" test)" "Finished: 2 of 2"
out="$(IMAGE_TRANSFORM_NO_WINDOW=1 bash "$S/heic-to-tiff.sh" "$PRG" "$PRG/out" --progress-window)"
has "--progress-window turns the progress file on" "$out" "progress: "
printf 'state=running\npid=%s\ndone=3\ntotal=9\nelapsed_seconds=12\neta_seconds=75\ncurrent=x.HEIC\nverified=3\nconverted=0\nexists=0\ncollision=0\nfailed=0\n' "$$" > "$PRG/running.status"
has "status reports a running run with time left" "$(bash "$S/status.sh" "$PRG/running.status" || true)" "running: 3 of 9 done (3 verified, 0 unverified, 0 already existed, 0 in a collision, 0 failed), 12s so far, about 1m15s left. Now: x.HEIC"
has "the progress window shows count, time left and current file" "$(osascript -l JavaScript "$J" "$PRG/running.status" "Converting" test)" "3 of 9 done, about 1m15s left | 3 converted, 0 already existed, 0 in a collision, 0 failed"
is "status exits 7 while running" "$(code bash "$S/status.sh" "$PRG/running.status")" 7
# stopping: a throwaway process stands in for a run
( trap 'exit 0' TERM; sleep 30 & wait ) & victim=$!
sed "s/^pid=.*/pid=$victim/" "$PRG/running.status" > "$PRG/victim.status"
is "stop.sh asks a running run to stop" "$(code bash "$S/stop.sh" "$PRG/victim.status")" 0
sleep 1
is "the process it named has stopped" "$(kill -0 "$victim" 2>/dev/null && echo alive || echo gone)" "gone"
is "stop.sh on a run that is not running exits 1" "$(code bash "$S/stop.sh" "$PRG/victim.status")" 1
is "stop.sh on a finished run exits 1" "$(code bash "$S/stop.sh" "$pf")" 1
is "stop.sh on a missing file is a usage error" "$(code bash "$S/stop.sh" "$PRG/none.status")" 2
( trap 'exit 0' TERM; sleep 30 & wait ) & victim=$!
sed "s/^pid=.*/pid=$victim/" "$PRG/running.status" > "$PRG/victim2.status"
has "the window's Stop button sends the stop" "$(osascript -l JavaScript "$J" "$PRG/victim2.status" "Converting" stop)" "stop sent: true"
sleep 1
is "the process the window named has stopped" "$(kill -0 "$victim" 2>/dev/null && echo alive || echo gone)" "gone"
sed 's/^pid=.*/pid=999999/' "$PRG/running.status" > "$PRG/dead.status"
has "a run whose process is gone is reported as stopped" "$(bash "$S/status.sh" "$PRG/dead.status" || true)" "stopped before finishing: 3 of 9"
is "status exits 8 when stopped" "$(code bash "$S/status.sh" "$PRG/dead.status")" 8
is "status on a missing file is a usage error" "$(code bash "$S/status.sh" "$PRG/none.status")" 2
is "status on a file that is not a progress file is refused" "$(code bash "$S/status.sh" "$PRG/taken.txt")" 2

# --- a file that is not an image fails on its own and is reported
BAD="$T/bad"; mkdir -p "$BAD"
echo "this is not a HEIC" > "$BAD/broken.HEIC"
cp "$SRC/IMG_0001.HEIC" "$BAD/good.HEIC"
is "a failed file makes the exit code 1" "$(code bash "$S/heic-to-tiff.sh" "$BAD" "$BAD/out")" 1
exists "the good file beside it was still converted" "$BAD/out/good.tif"
absent "the broken file produced nothing" "$BAD/out/broken.tif"
is "nothing left behind after a failure" "$(ls -A "$BAD/out" | grep -c '^\.' || true)" 0
is "the broken source is still there" "$(cat "$BAD/broken.HEIC")" "this is not a HEIC"

finish
