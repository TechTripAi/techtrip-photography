#!/usr/bin/env bash
# list.sh - number the files a recipe would work on, for choosing some of them.
#
# Usage: list.sh <source-dir> [<dest-dir>] [--recursive] [--recipe heic-to-tiff]
#
# Prints one tab-separated row per source file in <source-dir>, sorted by
# name: number, file name, size, pixels, bits per channel, colour profile
# and status. The numbers are the ones --select takes. With --recursive the
# subfolders are read too and names are paths relative to <source-dir>; give
# the same flag to the recipe, or the numbers will not match.
#
# Status: "new" would be converted; "exists" an output of that name is
# already in <dest-dir> and would be skipped; "collision" another source
# would produce the same output name, so neither is converted.
# Without <dest-dir>, status is "new" or "collision" only. Reads only.
#
# Exit codes: 0 listed; 1 no matching files; 2 usage.
set -eu
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
. "$SCRIPT_DIR/lib/common.sh"

usage() { echo "usage: list.sh <source-dir> [<dest-dir>] [--recursive] [--recipe <name>]" >&2; exit 2; }
src=""; dest=""; recipe=heic-to-tiff; depth=top
while [ $# -gt 0 ]; do
    case "$1" in
        --recipe) [ $# -ge 2 ] || usage; recipe="$2"; shift 2 ;;
        --recursive) depth=all; shift ;;
        -*) usage ;;
        *) if [ -z "$src" ]; then src="$1"; elif [ -z "$dest" ]; then dest="$1"; else usage; fi; shift ;;
    esac
done
[ -n "$src" ] || usage
[ -d "$src" ] || { echo "list: not a folder: $src" >&2; exit 2; }
case "$recipe" in
    heic-to-tiff) exts="heic heif"; outext=tif ;;
    *) echo "list: unknown recipe '$recipe'" >&2; exit 2 ;;
esac

work_new
trap work_clean EXIT
# shellcheck disable=SC2086
list_sources "$src" "$depth" $exts > "$WORK/list"
count="$(wc -l < "$WORK/list" | tr -d ' ')"
if [ "$count" = 0 ]; then
    echo "list: no $(printf '%s' "$exts" | tr ' ' '/') files in $src" >&2
    exit 1
fi
dup_stems < "$WORK/list" > "$WORK/dups"

tab="$(printf '\t')"
printf '#\tFile\tSize\tPixels\tBits\tProfile\tStatus\n'
n=0
while IFS= read -r name <&3; do
    n=$((n + 1))
    f="$src/$name"; st="${name%.*}"
    IFS="$tab" read -r w h b p <<EOF
$(img_props "$f")
EOF
    status=new
    if grep -qxF -- "$(lower "$st")" "$WORK/dups"; then
        status=collision
    elif [ -n "$dest" ] && { [ -e "$dest/$st.$outext" ] || [ -L "$dest/$st.$outext" ]; }; then
        status=exists
    fi
    printf '%s\t%s\t%s\t%sx%s\t%s\t%s\t%s\n' "$n" "$name" "$(human "$(fsize "$f")")" "$w" "$h" "$b" "$p" "$status"
done 3< "$WORK/list"
