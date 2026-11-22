#!/usr/bin/env bash
# pick.sh - let the user tick the files to work on, in a window with checkboxes.
#
# Usage: pick.sh <source-dir> [<dest-dir>] [--recursive] [--recipe heic-to-tiff]
#
# Opens a window on the user's screen listing the source files sorted by
# name, one checkbox each, with size, pixels and status beside the name.
# Nothing is ticked to begin with. Prints the ticked files' numbers on one
# line, ready for --select: "1,3,7". The numbers are the ones list.sh shows.
# Reads only; converts nothing.
#
# The window is a macOS one, opened through osascript, so it appears whatever
# AI tool or terminal started this script. The script waits until the window
# is closed.
#
# Exit codes: 0 a selection was printed; 1 no matching files; 2 usage;
# 5 no window can be opened here (not macOS, or no screen session), fall back
# to list.sh and numbers; 6 the user cancelled or ticked nothing.
set -eu
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
. "$SCRIPT_DIR/lib/common.sh"

if ! is_macos || ! have osascript; then
    echo "pick: no checkbox window is available on this system; use list.sh and choose by number" >&2
    exit 5
fi

folder="$(basename "${1:-}")"
work_new
trap work_clean EXIT
rc=0
bash "$SCRIPT_DIR/list.sh" "$@" > "$WORK/rows" || rc=$?
[ "$rc" = 0 ] || exit "$rc"

# One label per file: "name   size   pixels   status", in list.sh's order.
tab="$(printf '\t')"
set --
while IFS="$tab" read -r n name size pixels bits profile status <&3; do
    [ "$n" = "#" ] && continue
    set -- "$@" "$(printf '%-44s %9s  %11s  %s' "$name" "$size" "$pixels" "$status")"
done 3< "$WORK/rows"
count=$#

cat > "$WORK/pick.js" <<'EOF'
ObjC.import('Cocoa');
function run(argv) {
    var title = argv[0], message = argv[1], preset = argv[2], items = argv.slice(3);
    var app = $.NSApplication.sharedApplication;
    app.setActivationPolicy($.NSApplicationActivationPolicyAccessory);
    var rowH = 22, width = 720;
    var docH = items.length * rowH;
    var viewH = Math.min(docH, 440);
    var doc = $.NSView.alloc.initWithFrame($.NSMakeRect(0, 0, width, docH));
    var font = $.NSFont.userFixedPitchFontOfSize(12);
    var boxes = [];
    for (var i = 0; i < items.length; i++) {
        var b = $.NSButton.alloc.initWithFrame($.NSMakeRect(4, (items.length - 1 - i) * rowH, width - 8, rowH));
        b.setButtonType($.NSSwitchButton);
        b.title = $(items[i]);
        b.font = font;
        doc.addSubview(b);
        boxes.push(b);
    }
    var scroll = $.NSScrollView.alloc.initWithFrame($.NSMakeRect(0, 0, width + 18, viewH));
    scroll.hasVerticalScroller = true;
    scroll.borderType = $.NSBezelBorder;
    scroll.documentView = doc;
    doc.scrollPoint($.NSMakePoint(0, docH));
    var alert = $.NSAlert.alloc.init;
    alert.messageText = $(title);
    alert.informativeText = $(message);
    alert.addButtonWithTitle($('Use ticked files'));
    alert.addButtonWithTitle($('Cancel'));
    alert.accessoryView = scroll;
    if (preset !== '') {
        // test hook: tick the given numbers and skip showing the window
        preset.split(',').forEach(function (n) { boxes[parseInt(n, 10) - 1].state = 1; });
    } else {
        app.activateIgnoringOtherApps(true);
        if (alert.runModal !== $.NSAlertFirstButtonReturn) return 'CANCELLED';
    }
    var picked = [];
    for (var j = 0; j < boxes.length; j++) if (boxes[j].state == 1) picked.push(String(j + 1));
    return picked.join(',');
}
EOF

title="Choose the files to convert"
message="$count files in $folder, sorted by name. Tick the ones you want. Files marked exists or collision are skipped even if ticked."
reply="$(osascript -l JavaScript "$WORK/pick.js" "$title" "$message" "${IMAGE_TRANSFORM_PICK_TEST:-}" "$@" 2>"$WORK/err")" || {
    echo "pick: the window could not be opened ($(head -1 "$WORK/err")); use list.sh and choose by number" >&2
    exit 5
}
if [ "$reply" = CANCELLED ]; then echo "pick: cancelled; nothing was chosen" >&2; exit 6; fi
if [ -z "$reply" ]; then echo "pick: nothing was ticked" >&2; exit 6; fi
printf '%s\n' "$reply"
