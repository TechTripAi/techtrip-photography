#!/usr/bin/env bash
# heic-to-tiff.sh - convert HEIC/HEIF images to TIFF with no further loss.
#
# Usage: heic-to-tiff.sh <source-dir> <dest-dir> [options]
#
#   --select <list>      which files, by the numbers list.sh prints:
#                        "all" (default), or numbers and ranges: "1-5,9"
#   --recursive          also read subfolders; each output goes in the same
#                        subfolder of <dest-dir>
#   --dry-run            say what would happen; write nothing
#   --no-verify          skip the check of each output against its source
#   --compression <c>    lzw (default) or none; both are lossless
#   --progress-file <p>  keep a small status file up to date while running,
#                        for status.sh to read: "auto" makes one in the temp
#                        folder and prints its path first; a path is used as
#                        given and refused if anything is already there
#   --progress-window    show a small window with a progress bar while it
#                        runs; it closes itself at the end (macOS)
#   --report <md|csv>    also write a report file
#   --report-dir <dir>   where the report goes (default: <dest-dir>)
#
# Each source is decoded by macOS (sips), written as TIFF at the source's
# own bit depth with its colour profile, and given the source's metadata.
# An HDR gain map and other auxiliary images are not carried; the TIFF is
# the standard image.
#
# What it never does: change, move or delete a source; replace a file that
# already exists (that source is skipped and reported); remove anything but
# temp files this run made.
#
# Exit codes: 0 done, nothing failed; 1 at least one file failed, or no
# source files; 2 usage; 3 a tool is missing; 4 operating system not
# supported.
set -eu
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
. "$SCRIPT_DIR/lib/common.sh"

usage() {
    echo "usage: heic-to-tiff.sh <source-dir> <dest-dir> [--select <list>] [--recursive] [--dry-run] [--no-verify] [--compression lzw|none] [--progress-file auto|<path>] [--progress-window] [--report md|csv] [--report-dir <dir>]" >&2
    exit 2
}

src=""; dest=""; sel=all; depth=top; dry=0; verify=1; comp=lzw; report=""; report_dir=""; progress=""; window=0
while [ $# -gt 0 ]; do
    case "$1" in
        --select)      [ $# -ge 2 ] || usage; sel="$2"; shift 2 ;;
        --recursive)   depth=all; shift ;;
        --dry-run)     dry=1; shift ;;
        --no-verify)   verify=0; shift ;;
        --compression) [ $# -ge 2 ] || usage; comp="$2"; shift 2 ;;
        --progress-file) [ $# -ge 2 ] || usage; progress="$2"; shift 2 ;;
        --progress-window) window=1; shift ;;
        --report)      [ $# -ge 2 ] || usage; report="$2"; shift 2 ;;
        --report-dir)  [ $# -ge 2 ] || usage; report_dir="$2"; shift 2 ;;
        -*)            usage ;;
        *) if [ -z "$src" ]; then src="$1"; elif [ -z "$dest" ]; then dest="$1"; else usage; fi; shift ;;
    esac
done
[ -n "$src" ] && [ -n "$dest" ] || usage
[ -d "$src" ] || { echo "heic-to-tiff: not a folder: $src" >&2; exit 2; }
case "$comp" in
    lzw)  tiffcomp="lzw:2"; comp_name="LZW" ;;
    none) tiffcomp="none";  comp_name="None" ;;
    *) usage ;;
esac
case "$report" in ""|md|csv) ;; *) usage ;; esac

if [ "$dry" = 0 ]; then
    bash "$SCRIPT_DIR/preflight.sh" --recipe heic-to-tiff --quiet || exit $?
fi

PART=""; LOCK=""
part_clean() {
    [ -n "$PART" ] && [ -f "$PART" ] && rm -f "$PART"
    [ -n "$LOCK" ] && [ -f "$LOCK" ] && rm -f "$LOCK"
    PART=""; LOCK=""
    return 0
}
FINISHED=0; k=0; selected=0; start=0
cleanup() {
    bar_clear
    part_clean
    if [ "$FINISHED" = 0 ] && [ -n "$PROGRESS" ] && [ -f "${LOG:-}" ]; then
        # count what was finished, not the file that was under way
        progress_write stopped "$(wc -l < "$LOG" | tr -d ' ')" "$selected" "$(( $(date +%s) - start ))" "" "" "$LOG"
    fi
    work_clean
}
work_new
trap cleanup EXIT
trap 'exit 130' INT TERM

src="$(abs_dir "$src")"
list_sources "$src" "$depth" heic heif > "$WORK/list"
count="$(wc -l < "$WORK/list" | tr -d ' ')"
if [ "$count" = 0 ]; then
    echo "heic-to-tiff: no HEIC or HEIF files in $src" >&2
    exit 1
fi
dup_stems < "$WORK/list" > "$WORK/dups"

if [ "$sel" = all ]; then
    awk -v n="$count" 'BEGIN { for (i = 1; i <= n; i++) print i }' > "$WORK/sel"
else
    expand_selection "$sel" "$count" > "$WORK/sel.raw" || exit 2
    sort -n -u "$WORK/sel.raw" > "$WORK/sel"
    [ -s "$WORK/sel" ] || { echo "heic-to-tiff: the selection is empty" >&2; exit 2; }
fi

if [ "$dry" = 0 ]; then
    mkdir -p "$dest" || { echo "heic-to-tiff: cannot create $dest" >&2; exit 1; }
    dest="$(abs_dir "$dest")"
elif [ -d "$dest" ]; then
    dest="$(abs_dir "$dest")"
fi

META_TAGS="-DateTimeOriginal -OffsetTimeOriginal -GPSLatitude -GPSLongitude -Make -Model -LensModel -ExposureTime -FNumber -ISO -FocalLength"

# convert_one <source> <output>: sets STATUS and NOTE. Builds the TIFF under
# a temp name in the destination, checks it, and only then gives it its name.
convert_one() {
    # locals: the caller's loop has variables of its own named f, out and b
    local f="$1" out="$2" raw="$WORK/raw.tif" bmp_a="$WORK/a.bmp" bmp_b="$WORK/b.bmp" info m1 m2
    STATUS=failed; NOTE=""
    rm -f "$raw"

    # 1. decode with Apple's decoder into an uncompressed TIFF with metadata
    if ! sips -s format tiff "$f" --out "$raw" >/dev/null 2>&1; then
        NOTE="could not be decoded"; return 0
    fi
    # 2. recompress losslessly, in strips. sips ignores its own lzw option
    #    and writes one huge tile, which some readers refuse.
    LOCK="$(mktemp "$dest/.image-transform.XXXXXX" 2>/dev/null)" || {
        LOCK=""; NOTE="cannot write to the destination"; return 0; }
    PART="$LOCK.tif"
    if [ -e "$PART" ]; then PART=""; part_clean; NOTE="temp name already taken"; return 0; fi
    if ! tiffcp -s -r 64 -c "$tiffcomp" "$raw" "$PART" >/dev/null 2>&1; then
        NOTE="could not be written as TIFF"; part_clean; return 0
    fi
    # 3. tiffcp drops EXIF, GPS and XMP; copy them back, values unrounded
    exiftool -q -q -n -overwrite_original -tagsfromfile "$raw" -all:all -makernotes "$PART" >/dev/null 2>&1 || true

    if [ "$verify" = 1 ]; then
        rm -f "$bmp_a" "$bmp_b"
        if sips -s format bmp "$f" --out "$bmp_a" >/dev/null 2>&1 &&
           sips -s format bmp "$PART" --out "$bmp_b" >/dev/null 2>&1; then
            if ! cmp -s "$bmp_a" "$bmp_b"; then
                NOTE="pixels differ from the source; nothing was kept"; part_clean; return 0
            fi
        else
            NOTE="the output could not be read back; nothing was kept"; part_clean; return 0
        fi
        rm -f "$bmp_a" "$bmp_b"
        info="$(tiffinfo "$PART" 2>/dev/null || true)"
        case "$info" in
            *"Compression Scheme: $comp_name"*) ;;
            *) NOTE="compression is not $comp_name; nothing was kept"; part_clean; return 0 ;;
        esac
        # shellcheck disable=SC2086
        m1="$(exiftool -s $META_TAGS "$f" 2>/dev/null || true)"
        # shellcheck disable=SC2086
        m2="$(exiftool -s $META_TAGS "$PART" 2>/dev/null || true)"
        if [ "$m1" != "$m2" ]; then
            printf '%s\n' "$m1" > "$WORK/m1"; printf '%s\n' "$m2" > "$WORK/m2"
            NOTE="metadata differs: $(diff "$WORK/m1" "$WORK/m2" | grep '^[<>]' | awk '{print $2}' | sort -u | tr '\n' ' ')"
        fi
    fi

    # 4. give it its name, without replacing anything
    if [ -e "$out" ] || [ -L "$out" ]; then
        STATUS=skipped-exists; NOTE="a file of that name appeared during the run"; part_clean; return 0
    fi
    mv -n "$PART" "$out" 2>/dev/null || true
    if [ -e "$PART" ]; then
        STATUS=skipped-exists; NOTE="a file of that name appeared during the run"; part_clean; return 0
    fi
    PART=""; part_clean
    if [ "$verify" = 1 ]; then STATUS=verified; else STATUS=converted; fi
    return 0
}

LOG="$WORK/log.tsv"; : > "$LOG"
tab="$(printf '\t')"
selected="$(wc -l < "$WORK/sel" | tr -d ' ')"
[ "$window" = 1 ] && [ -z "$progress" ] && progress=auto
if [ -n "$progress" ] && [ "$dry" = 0 ]; then
    progress_open "$progress" || { echo "heic-to-tiff: cannot use $progress as the progress file; something is already there" >&2; exit 2; }
    echo "progress: $PROGRESS"
fi
start="$(date +%s)"; n_conv=0; eta=""

# after_file <current name>: work out the time left, refresh the progress
# file and the bar. Skips take no time, so the estimate comes from the files
# that were really converted.
after_file() {
    local elapsed
    elapsed=$(( $(date +%s) - start ))
    eta=""
    if [ "$n_conv" -gt 0 ] && [ "$k" -lt "$selected" ]; then
        eta=$(( elapsed * (selected - k) / n_conv ))
    fi
    progress_write running "$k" "$selected" "$elapsed" "$eta" "$1" "$LOG"
    bar_draw "$k" "$selected" "$eta"
}
progress_write running 0 "$selected" 0 "" "" "$LOG"

# The window is a separate process that only reads the progress file. It is
# detached from this script's output so nothing waits on it, and it closes
# itself when the run finishes or stops.
if [ "$window" = 1 ] && [ "$dry" = 0 ]; then
    if [ -n "${IMAGE_TRANSFORM_NO_WINDOW:-}" ]; then
        echo "progress window: off"
    elif is_macos && have osascript; then
        osascript -l JavaScript "$SCRIPT_DIR/lib/progress-window.js" "$PROGRESS" "Converting to TIFF" \
            </dev/null >/dev/null 2>&1 &
        echo "progress window: open"
    else
        echo "progress window: not available here"
    fi
fi

n=0
while IFS= read -r name <&3; do
    n=$((n + 1))
    grep -qx "$n" "$WORK/sel" || continue
    k=$((k + 1)); tag="[$k/$selected]"
    f="$src/$name"; st="${name%.*}"; out="$dest/$st.tif"
    IFS="$tab" read -r w h b p <<EOF
$(img_props "$f")
EOF
    sb="$(fsize "$f")"

    if grep -qxF -- "$(lower "$st")" "$WORK/dups"; then
        log_row "$LOG" "$n" "$f" "" skipped-collision "$sb" "" "$w" "$h" "$b" "$p" "another source would also become $st.tif"
        bar_clear; printf '%s collision  %s  (another source would also become %s.tif)\n' "$tag" "$name" "$st"
        after_file "$name"; continue
    fi
    if [ -e "$out" ] || [ -L "$out" ]; then
        log_row "$LOG" "$n" "$f" "$out" skipped-exists "$sb" "" "$w" "$h" "$b" "$p" "output already exists; left as it is"
        bar_clear; printf '%s exists     %s  (%s.tif is already there; left as it is)\n' "$tag" "$name" "$st"
        after_file "$name"; continue
    fi
    if [ "$dry" = 1 ]; then
        log_row "$LOG" "$n" "$f" "$out" would-convert "$sb" "" "$w" "$h" "$b" "$p" ""
        printf '%s would convert  %s -> %s.tif\n' "$tag" "$name" "$st"
        continue
    fi

    mkdir -p "$(dirname "$out")" 2>/dev/null || true
    convert_one "$f" "$out"
    n_conv=$((n_conv + 1))
    ob=""; [ -f "$out" ] && [ "$STATUS" != skipped-exists ] && ob="$(fsize "$out")"
    if [ "$STATUS" = failed ] || [ "$STATUS" = skipped-exists ]; then
        log_row "$LOG" "$n" "$f" "" "$STATUS" "$sb" "" "$w" "$h" "$b" "$p" "$NOTE"
    else
        log_row "$LOG" "$n" "$f" "$out" "$STATUS" "$sb" "$ob" "$w" "$h" "$b" "$p" "$NOTE"
    fi
    after_file "$name"
    left=""; [ -n "$eta" ] && [ "$eta" -gt 0 ] && left="  about $(fmt_dur "$eta") left"
    bar_clear
    if [ "$STATUS" = failed ] || [ "$STATUS" = skipped-exists ]; then
        printf '%s %-10s %s  (%s)%s\n' "$tag" "$STATUS" "$name" "$NOTE" "$left"
    else
        printf '%s %-10s %s.tif  (%s -> %s)%s%s\n' "$tag" "$STATUS" "$st" "$(human "$sb")" "$(human "$ob")" "${NOTE:+  note: $NOTE}" "$left"
    fi
    bar_draw "$k" "$selected" "$eta"
done 3< "$WORK/list"
bar_clear

took=$(( $(date +%s) - start ))
progress_write done "$k" "$selected" "$took" "" "" "$LOG"
FINISHED=1
c_ver="$(log_count "$LOG" verified)"; c_conv="$(log_count "$LOG" converted)"
c_exist="$(log_count "$LOG" skipped-exists)"; c_coll="$(log_count "$LOG" skipped-collision)"
c_fail="$(log_count "$LOG" failed)"; c_would="$(log_count "$LOG" would-convert)"

echo
if [ "$dry" = 1 ]; then
    echo "dry run: $count source files, $selected selected: $c_would would be converted, $c_exist already exist, $c_coll in a name collision. Nothing was written."
else
    echo "$count source files, $selected selected: $c_ver verified, $c_conv converted without verification, $c_exist already existed, $c_coll in a name collision, $c_fail failed. Took $(fmt_dur "$took")."
fi

if [ -n "$report" ] && [ "$dry" = 0 ]; then
    [ -n "$report_dir" ] || report_dir="$dest"
    mkdir -p "$report_dir"
    rp="$(unique_path "$report_dir/image-transform-report-$(date '+%Y%m%d-%H%M%S')" "$report")"
    settings="HEIC to TIFF, compression $comp_name, verification $([ "$verify" = 1 ] && echo on || echo off)"
    if [ "$report" = md ]; then
        report_md "$LOG" "Image transform report" "$src" "$dest" "$settings" | write_new "$rp"
    else
        report_csv "$LOG" | write_new "$rp"
    fi && echo "report: $rp" || echo "report: could not be written to $report_dir" >&2
fi

[ "$c_fail" = 0 ]
