#!/usr/bin/env bash
# stop.sh - ask a running transformation to stop. The same as pressing Stop
# in its progress window, or Ctrl-C in the terminal it runs in.
#
# Usage: stop.sh <progress-file>
#
# The run finishes nothing half-way: the file being worked on is dropped,
# files already done are kept, and the same command run again carries on from
# there. Touches no image file itself.
#
# Exit codes: 0 the run was asked to stop; 1 it was not running; 2 usage, or
# no such progress file.
set -eu
[ $# -eq 1 ] || { echo "usage: stop.sh <progress-file>" >&2; exit 2; }
[ -f "$1" ] || { echo "stop: no progress file at $1" >&2; exit 2; }
state="$(awk -F= '$1 == "state" { print $2; exit }' "$1" | tr -d '\r')"
pid="$(awk -F= '$1 == "pid" { print $2; exit }' "$1" | tr -d '\r')"
case "$pid" in ""|*[!0-9]*) echo "stop: $1 is not a progress file" >&2; exit 2 ;; esac
if [ "$state" != running ] || ! kill -0 "$pid" 2>/dev/null; then
    echo "stop: that run is not running"
    exit 1
fi
kill -TERM "$pid"
echo "stop: asked the run to stop; files already done are kept"
