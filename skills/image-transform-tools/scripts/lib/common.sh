#!/usr/bin/env bash
# Shared helpers for the image-transform-tools scripts. Sourced, never run.
#
# The rules every script here keeps:
#   - a source file is never modified, moved or deleted
#   - an existing file is never overwritten
#   - the only files removed are temp files this run created, by exact path

have()     { command -v "$1" >/dev/null 2>&1; }
is_macos() { [ "$(uname -s 2>/dev/null)" = Darwin ]; }
fsize()    { wc -c < "$1" | tr -d ' '; }
lower()    { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }
abs_dir()  { (cd "$1" 2>/dev/null && pwd -P); }

human() {  # bytes -> "20.3 MB"
    awk -v b="$1" 'BEGIN{ if (b !~ /^[0-9]+$/) { print "?"; exit }
        if (b >= 1073741824) printf "%.1f GB", b/1073741824
        else if (b >= 1048576) printf "%.1f MB", b/1048576
        else if (b >= 1024) printf "%.0f KB", b/1024
        else printf "%d B", b }'
}

fmt_dur() {  # seconds -> "45s", "1m20s", "1h05m"
    awk -v s="$1" 'BEGIN { s = int(s)
        if (s >= 3600) printf "%dh%02dm", s/3600, (s%3600)/60
        else if (s >= 60) printf "%dm%02ds", s/60, s%60
        else printf "%ds", s }'
}

# --- progress ------------------------------------------------------------
# A progress file is a few key=value lines that a run rewrites after every
# file, so something else (status.sh, or a person) can see how far it is.
# It is this run's own file: "auto" makes one in the temp folder, and a
# given path is refused if anything is already there.
PROGRESS=""
progress_open() {  # progress_open <auto|path>
    if [ "$1" = auto ]; then
        PROGRESS="$(mktemp "${TMPDIR:-/tmp}/image-transform-progress.XXXXXX")" || return 1
    else
        : | write_new "$1" || return 1
        PROGRESS="$1"
    fi
}
# progress_write <state> <done> <total> <elapsed> <eta or empty> <current> <logfile>
progress_write() {
    [ -n "$PROGRESS" ] || return 0
    {
        printf 'state=%s\npid=%s\ndone=%s\ntotal=%s\nelapsed_seconds=%s\neta_seconds=%s\ncurrent=%s\n' \
            "$1" "$$" "$2" "$3" "$4" "$5" "$6"
        awk -F'\t' '{ c[$4]++ } END {
            printf "verified=%d\nconverted=%d\nexists=%d\ncollision=%d\nfailed=%d\n",
                c["verified"], c["converted"], c["skipped-exists"], c["skipped-collision"], c["failed"] }' "$7"
        printf 'updated=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    } > "$PROGRESS"
}

# A bar on the terminal, only when a person is watching one (stderr is a
# terminal). Captured output gets the "[12/61]" counters on each line instead.
BAR=0
[ -t 2 ] && BAR=1
bar_clear() { [ "$BAR" = 1 ] && printf '\r\033[K' >&2; return 0; }
bar_draw() {  # bar_draw <done> <total> <eta or empty>
    [ "$BAR" = 1 ] || return 0
    awk -v d="$1" -v t="$2" -v e="$3" 'BEGIN { w = 30; f = (t > 0 ? int(w * d / t) : 0)
        s = ""; for (i = 0; i < w; i++) s = s (i < f ? "#" : ".")
        printf "\r\033[K[%s] %d/%d", s, d, t
        if (e != "") { e = int(e)
            if (e >= 60) printf "  about %dm%02ds left", e/60, e%60; else printf "  about %ds left", e } }' >&2
}

# --- temp work directory -------------------------------------------------
# WORK holds this run's scratch files. work_clean removes only the files in
# it and then the empty directory; nothing is removed recursively.
WORK=""
work_new() {
    WORK="$(mktemp -d "${TMPDIR:-/tmp}/image-transform.XXXXXX")" || {
        printf 'cannot create a temp directory\n' >&2; exit 1; }
}
work_clean() {
    [ -n "$WORK" ] && [ -d "$WORK" ] || return 0
    for _f in "$WORK"/*; do
        [ -f "$_f" ] && rm -f "$_f"
    done
    rmdir "$WORK" 2>/dev/null || true
    WORK=""
}

# --- sources -------------------------------------------------------------
# list_sources <dir> <top|all> <ext> [<ext>...]: the files in <dir> with one
# of the extensions, any letter case; "top" reads the folder itself, "all"
# also reads its subfolders. One path per line, relative to <dir>, sorted by
# name without regard to letter case. list.sh, pick.sh and every recipe use
# this, so a file has the same number everywhere. Dot files and dot folders
# are left out; that also skips the "._name" companions macOS writes on
# non-Apple volumes.
list_sources() {
    _dir="$1"; _depth="$2"; shift 2
    for _e in "$@"; do
        if [ "$_depth" = all ]; then
            (cd "$_dir" && find . -type f -iname "*.$_e" ! -name '.*' ! -path '*/.*/*' 2>/dev/null)
        else
            (cd "$_dir" && find . -maxdepth 1 -type f -iname "*.$_e" ! -name '.*' 2>/dev/null)
        fi
    done | sed 's|^\./||' | LC_ALL=C sort -u | LC_ALL=C sort -f -s
}

# dup_stems: relative paths on stdin; prints each lowercased path without its
# extension that occurs more than once. Two such sources would produce the
# same output file. The same name in two different subfolders is not a clash.
dup_stems() {
    while IFS= read -r _p; do
        printf '%s\n' "${_p%.*}"
    done | tr '[:upper:]' '[:lower:]' | LC_ALL=C sort | uniq -d
}

# expand_selection "<1-5,9 12>" <count>: one number per line. Exit 2 on a
# selection that is not numbers and ranges within 1..count.
expand_selection() {
    printf '%s\n' "$1" | tr ', ' '\n\n' | awk -v max="$2" '
        NF == 0 { next }
        !/^[0-9]+(-[0-9]+)?$/ { printf "not a number or range: %s\n", $0 > "/dev/stderr"; bad = 1; exit }
        { n = split($0, r, "-"); a = r[1] + 0; b = (n == 2 ? r[2] + 0 : a)
          if (a < 1 || b > max || a > b) {
              printf "selection %s is outside 1-%d\n", $0, max > "/dev/stderr"; bad = 1; exit }
          for (i = a; i <= b; i++) print i }
        END { exit bad ? 2 : 0 }'
}

# img_props <file>: "width<TAB>height<TAB>bits<TAB>profile", "?" where unknown.
img_props() {
    if have sips; then
        sips -g pixelWidth -g pixelHeight -g bitsPerSample -g profile "$1" 2>/dev/null
    fi | awk -F': ' '
        /pixelWidth/    { w = $2 }
        /pixelHeight/   { h = $2 }
        /bitsPerSample/ { b = $2 }
        /profile:/      { p = $2 }
        END { printf "%s\t%s\t%s\t%s\n", (w ? w : "?"), (h ? h : "?"), (b ? b : "?"), (p ? p : "none") }'
}

# unique_path <base> <ext>: "<base>.<ext>", or "<base>-2.<ext>", "-3" ... so
# that the path printed does not exist yet.
unique_path() {
    _p="$1.$2"; _n=2
    while [ -e "$_p" ]; do _p="$1-$_n.$2"; _n=$((_n + 1)); done
    printf '%s' "$_p"
}

# --- run log and reports -------------------------------------------------
# A run log is a tab-separated file, one row per source file:
#   n  source  output  status  src_bytes  out_bytes  width  height  bits  profile  note
log_row() {  # log_row <logfile> <11 fields>
    _log="$1"; shift
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$@" >> "$_log"
}

log_count() {  # log_count <logfile> <status>
    awk -F'\t' -v s="$2" '$4 == s { n++ } END { print n + 0 }' "$1"
}

# report_md <logfile> <title> <source dir> <dest dir> <settings line>
report_md() {
    printf '# %s\n\n' "$2"
    printf -- '- **Source:** `%s`\n' "$3"
    printf -- '- **Destination:** `%s`\n' "$4"
    printf -- '- **Settings:** %s\n' "$5"
    printf -- '- **Run:** %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    printf '| # | Source | Output | Status | Source size | Output size | Pixels | Bits | Profile | Note |\n'
    printf '|---|---|---|---|---|---|---|---|---|---|\n'
    awk -F'\t' '
        function hs(b) { if (b !~ /^[0-9]+$/) return "";
            if (b >= 1048576) return sprintf("%.1f MB", b/1048576);
            if (b >= 1024) return sprintf("%.0f KB", b/1024); return b " B" }
        function rel(p, root) { return (index(p, root "/") == 1 ? substr(p, length(root) + 2) : p) }
        { gsub(/\|/, "/", $11)
          printf "| %s | %s | %s | %s | %s | %s | %sx%s | %s | %s | %s |\n",
              $1, rel($2, src), ($3 == "" ? "" : rel($3, dst)), $4, hs($5), hs($6), $7, $8, $9, $10, $11 }' src="$3" dst="$4" "$1"
    printf '\n'
    awk -F'\t' '{ c[$4]++; if ($6 ~ /^[0-9]+$/) out += $6 }
        END { printf "**Totals:**"; for (s in c) printf " %s %d;", s, c[s];
              printf " output written %.1f MB\n", out/1048576 }' "$1"
}

# report_csv <logfile>
report_csv() {
    printf 'n,source,output,status,source_bytes,output_bytes,width,height,bits,profile,note\n'
    awk -F'\t' '{ for (i = 1; i <= 11; i++) { v = $i; gsub(/"/, "\"\"", v);
              printf "%s\"%s\"", (i > 1 ? "," : ""), v }
          printf "\n" }' "$1"
}

# write_new <path>: stdin to <path>, refusing to replace an existing file.
write_new() {
    ( set -C; cat > "$1" ) 2>/dev/null
}
