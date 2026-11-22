#!/usr/bin/env bash
# status.sh - how far along is a run? Reads a progress file and says so in
# one line. Reads only.
#
# Usage: status.sh <progress-file>
#
# The progress file is the one a recipe keeps when it is given
# --progress-file. Prints, for example:
#   running: 23 of 61 done (21 verified, 2 already existed, 0 in a collision, 0 failed), 40s so far, about 1m05s left. Now: IMG_0042.HEIC
#   finished: 61 of 61 done (...), took 1m45s
#   stopped before finishing: 23 of 61 done (...). Run the same command again to carry on; finished files are skipped.
#
# Exit codes: 0 finished; 2 usage, or no such progress file; 7 still
# running; 8 stopped before finishing.
set -eu
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
. "$SCRIPT_DIR/lib/common.sh"

[ $# -eq 1 ] || { echo "usage: status.sh <progress-file>" >&2; exit 2; }
[ -f "$1" ] || { echo "status: no progress file at $1" >&2; exit 2; }

get() { awk -F= -v k="$2" '$1 == k { sub(/^[^=]*=/, ""); print; exit }' "$1" | tr -d '\r'; }
state="$(get "$1" state)"; pid="$(get "$1" pid)"
done_n="$(get "$1" done)"; total="$(get "$1" total)"
elapsed="$(get "$1" elapsed_seconds)"; eta="$(get "$1" eta_seconds)"; current="$(get "$1" current)"
counts="$(get "$1" verified) verified, $(get "$1" converted) unverified, $(get "$1" exists) already existed, $(get "$1" collision) in a collision, $(get "$1" failed) failed"
case "$done_n$total$elapsed" in *[!0-9]*|"") echo "status: $1 is not a progress file" >&2; exit 2 ;; esac

# A run that was killed outright cannot say so; if it claims to be running
# and its process is gone, it stopped.
if [ "$state" = running ]; then
    case "$pid" in ""|*[!0-9]*) ;; *) kill -0 "$pid" 2>/dev/null || state=stopped ;; esac
fi

case "$state" in
    done)
        echo "finished: $done_n of $total done ($counts), took $(fmt_dur "$elapsed")"
        exit 0 ;;
    running)
        left=""
        case "$eta" in ""|*[!0-9]*) ;; *) left=", about $(fmt_dur "$eta") left" ;; esac
        echo "running: $done_n of $total done ($counts), $(fmt_dur "$elapsed") so far$left.${current:+ Now: $current}"
        exit 7 ;;
    *)
        echo "stopped before finishing: $done_n of $total done ($counts). Run the same command again to carry on; finished files are skipped."
        exit 8 ;;
esac
