#!/usr/bin/env bash
# preflight.sh - is this machine ready to run a transformation?
#
# Usage: preflight.sh [--recipe heic-to-tiff] [--quiet]
#
# Prints one row per requirement: "ok" or "missing", the requirement, and
# where it was found or the command that installs it. Installs nothing.
# --quiet prints only when something is wrong.
#
# Exit codes: 0 ready; 2 usage; 3 a tool is missing; 4 this operating system
# is not supported by the recipe.
set -eu
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
. "$SCRIPT_DIR/lib/common.sh"

recipe=heic-to-tiff; quiet=0
while [ $# -gt 0 ]; do
    case "$1" in
        --recipe) [ $# -ge 2 ] || { echo "usage: preflight.sh [--recipe <name>] [--quiet]" >&2; exit 2; }
                  recipe="$2"; shift 2 ;;
        --quiet)  quiet=1; shift ;;
        *) echo "usage: preflight.sh [--recipe <name>] [--quiet]" >&2; exit 2 ;;
    esac
done

# tool<TAB>how to get it, per recipe
needs_for() {
    case "$1" in
        heic-to-tiff)
            printf 'sips\tpart of macOS\n'
            printf 'tiffcp\tbrew install libtiff\n'
            printf 'tiffinfo\tbrew install libtiff\n'
            printf 'exiftool\tbrew install exiftool\n' ;;
        *) return 1 ;;
    esac
}
needs="$(needs_for "$recipe")" || { echo "preflight: unknown recipe '$recipe'" >&2; exit 2; }

out=""; missing=0; os_ok=1
if is_macos; then
    out="$(printf 'ok       %-10s %s' "macOS" "$(sw_vers -productVersion 2>/dev/null || uname -r)")"
else
    os_ok=0
    out="$(printf 'missing  %-10s %s' "macOS" "this recipe decodes with Apple's own decoder and runs on macOS only; this is $(uname -s 2>/dev/null || echo unknown)")"
fi

tab="$(printf '\t')"
while IFS="$tab" read -r tool how; do
    [ -n "$tool" ] || continue
    if have "$tool"; then
        row="$(printf 'ok       %-10s %s' "$tool" "$(command -v "$tool")")"
    else
        missing=$((missing + 1))
        row="$(printf 'missing  %-10s %s' "$tool" "$how")"
    fi
    out="$out
$row"
done <<EOF
$needs
EOF

if [ "$os_ok" = 0 ]; then
    printf '%s\n' "$out"
    echo "preflight: not supported on this operating system"
    exit 4
fi
if [ "$missing" -gt 0 ]; then
    printf '%s\n' "$out"
    echo "preflight: not ready, $missing tool(s) missing. Run the install command shown, then try again."
    exit 3
fi
if [ "$quiet" = 0 ]; then
    printf '%s\n' "$out"
    echo "preflight: ready"
fi
