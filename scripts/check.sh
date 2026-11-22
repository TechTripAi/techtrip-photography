#!/usr/bin/env bash
# Repository health check for techtrip-photography. Read-only; exits non-zero on any failure.
# Usage: bash scripts/check.sh
set -eu
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"
fails=0
tour=photo-expert   # the tour skill; its name is fixed by the catalog's docs/packaging.md
ok()   { printf 'ok    %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1"; fails=$((fails + 1)); }
warn() { printf 'warn  %s\n' "$1"; }

# 1. shell syntax
for f in scripts/*.sh skills/*/scripts/*.sh skills/*/scripts/lib/*.sh tests/*.sh; do
    [ -f "$f" ] || continue
    if bash -n "$f" 2>/dev/null; then ok "syntax $f"; else fail "syntax $f"; fi
done

# 2. frontmatter: name equals dir, description length, model-invocable, README + tour coverage
for skill in skills/*/; do
    [ -d "$skill" ] || continue
    name="$(basename "$skill")"; md="$skill/SKILL.md"
    [ -f "$md" ] || { fail "$name: no SKILL.md"; continue; }
    fm_name="$(awk 'NR>1 && /^---/{exit} /^name:/{sub(/^name:[ \t]*/,""); print}' "$md" | tr -d '\r')"
    [ "$fm_name" = "$name" ] && ok "$name: name matches directory" || fail "$name: frontmatter name '$fm_name' != directory"
    desc="$(awk 'NR>1 && /^---/{exit} /^description:/{d=1; sub(/^description:[ \t]*/,""); s=$0; next} d && /^[a-z_-]+:/{d=0} d{s=s " " $0} END{print s}' "$md")"
    len=${#desc}
    [ "$len" -le 1024 ] && ok "$name: description $len chars" || fail "$name: description $len chars (max 1024)"
    grep -q '^disable-model-invocation: true' "$md" && fail "$name: must stay model-invocable" || ok "$name: model-invocable"
    grep -q "\*\*\`$name\`\*\*" README.md && ok "$name: listed in README" || fail "$name: not in README Skills included"
    if [ "$name" != "$tour" ] && [ -f "skills/$tour/SKILL.md" ]; then
        grep -q "$name" "skills/$tour/SKILL.md" && ok "$name: covered by $tour" || fail "$name: not mentioned in $tour"
    fi
done
# the tour skill exists and can be reached in plain words
if [ -f "skills/$tour/SKILL.md" ]; then
    ok "tour skill $tour present"
    tdesc="$(awk 'NR>1 && /^---/{exit} /^description:/{print}' "skills/$tour/SKILL.md")"
    for w in "tour" "how do I use"; do
        case "$tdesc" in *"$w"*) ok "$tour: description carries '$w'" ;; *) fail "$tour: description lacks '$w'" ;; esac
    done
else fail "no tour skill at skills/$tour"; fi
for other in brain-dump study-orientation sessions-briefing eng-playbook; do
    [ ! -d "skills/$other" ] && ok "no skill named $other (that name belongs to another plugin)" || fail "skills/$other exists; the tour here is $tour"
done

# 2b. every script and reference a SKILL.md names exists
for skill in skills/*/; do
    name="$(basename "$skill")"; md="$skill/SKILL.md"
    [ -f "$md" ] || continue
    for s in $(grep -oE '<scripts>/[a-z0-9-]+\.sh' "$md" | sed 's|<scripts>/||' | sort -u); do
        [ -f "$skill/scripts/$s" ] && ok "$name: script $s exists" || fail "$name: SKILL.md names scripts/$s, which does not exist"
    done
done
tt=skills/image-transform-tools
for r in $(grep -ohE 'references/[a-z0-9-]+\.md' skills/*/SKILL.md "$tt"/references/*.md 2>/dev/null | sort -u); do
    [ -f "$tt/$r" ] && ok "image-transform-tools: $r exists" || fail "a skill names $r, which does not exist"
done
for s in $(grep -ohE 'scripts/[a-z0-9-]+\.sh' "skills/$tour/SKILL.md" "$tt"/references/*.md 2>/dev/null | sort -u); do
    [ -f "$tt/$s" ] && ok "image-transform-tools: $s exists" || fail "a skill names $s, which does not exist"
done
if [ -f "$tt/SKILL.md" ]; then
    lines="$(wc -l < "$tt/SKILL.md" | tr -d ' ')"
    [ "$lines" -le 200 ] && ok "image-transform-tools: SKILL.md is $lines lines" || warn "image-transform-tools: SKILL.md is $lines lines; move detail into references/"
fi

# 2c. the safety rules, as far as text can show them (the tests show the rest)
src_files="$(ls skills/*/scripts/*.sh skills/*/scripts/lib/*.sh 2>/dev/null)"
code_lines() { grep -nE "$1" $src_files 2>/dev/null | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' || true; }
hits="$(code_lines '(^|[;&|[:space:]])rm[[:space:]]+-[A-Za-z]*[rR]')"
[ -z "$hits" ] && ok "no script deletes recursively" || { fail "a script deletes recursively:"; printf '%s\n' "$hits" | sed 's/^/      /'; }
hits="$(code_lines '(^|[;&|[:space:]])mv[[:space:]]' | grep -vE 'mv[[:space:]]+-n[[:space:]]' || true)"
[ -z "$hits" ] && ok "every mv is mv -n" || { fail "a script moves a file without -n:"; printf '%s\n' "$hits" | sed 's/^/      /'; }
hits="$(code_lines '(^|[;&|[:space:]])cp[[:space:]]')"
[ -z "$hits" ] && ok "no script copies over files" || { fail "a script uses cp; build under a mktemp name and mv -n instead:"; printf '%s\n' "$hits" | sed 's/^/      /'; }
hits="$(code_lines '(^|[;&|[:space:]])rm[[:space:]]' | grep -vE 'rm -f "\$(_f|raw|bmp_a|PART|LOCK)"( "\$bmp_b")?[[:space:]]*(;|$|&&)' || true)"
[ -z "$hits" ] && ok "rm is used only on the run's own temp files" || { fail "rm on something other than a known temp file:"; printf '%s\n' "$hits" | sed 's/^/      /'; }

# 2d. Agent Skills spec conformance (reference validator), claude-only keys stripped.
#     Stripped copies go under a fresh mktemp directory that the OS temp cleaner owns;
#     nothing here deletes anything.
if command -v uvx >/dev/null 2>&1; then
    tmp="$(mktemp -d "${TMPDIR:-/tmp}/ttph-check.XXXXXX")"
    for skill in skills/*/; do
        name="$(basename "$skill")"
        mkdir -p "$tmp/$name"
        awk 'NR==1{print; next} !fm && /^---/{fm=1} !fm && /^(argument-hint|disable-model-invocation):/{next} {print}' "$skill/SKILL.md" > "$tmp/$name/SKILL.md"
        if out="$(uvx --from skills-ref agentskills validate "$tmp/$name" 2>&1)"; then ok "$name: Agent Skills spec"
        else fail "$name: Agent Skills spec"; printf '%s\n' "$out" | sed 's/^/      /'; fi
    done
else
    warn "uvx not on PATH; skipped Agent Skills reference validator"
fi

# 3. versions and descriptions agree
if command -v node >/dev/null 2>&1; then
    v_root="$(node -e 'console.log(require("./plugin.json").version)')"
    v_claude="$(node -e 'console.log(require("./.claude-plugin/plugin.json").version)')"
    v_mkt="$(node -e 'console.log(require("./.claude-plugin/marketplace.json").plugins[0].version)')"
    v_log="$(grep -m1 -oE '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' CHANGELOG.md | tr -d '#[] ')"
    if [ "$v_root" = "$v_claude" ] && [ "$v_root" = "$v_log" ] && [ "$v_root" = "$v_mkt" ]; then ok "version $v_root agrees across both manifests, the marketplace entry and CHANGELOG"; else fail "version mismatch: plugin.json=$v_root claude=$v_claude marketplace=$v_mkt changelog=$v_log"; fi
    d_root="$(node -e 'console.log(require("./plugin.json").description)')"
    d_claude="$(node -e 'console.log(require("./.claude-plugin/plugin.json").description)')"
    [ "$d_root" = "$d_claude" ] && ok "descriptions agree across manifests" || fail "manifest descriptions differ"
    node -e 'const m=require("./plugin.json"); const allowed=new Set(["$schema","name","version","description","author","homepage","repository","license","keywords","extensions"]); const bad=Object.keys(m).filter(k=>!allowed.has(k)); if(bad.length){console.error("unknown fields: "+bad.join(",")); process.exit(1)} if(m.$schema!=="https://agent-plugins.org/schemas/1.0.0/plugin.schema.json"){console.error("bad $schema"); process.exit(1)}' && ok "plugin.json conforms to Agent Plugins 1.0.0 field set" || fail "plugin.json does not conform to Agent Plugins 1.0.0"
    for e in skills/*/evals/evals.json; do
        [ -f "$e" ] || continue
        node -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' "$e" 2>/dev/null && ok "$e parses" || fail "$e is not valid JSON"
    done
else
    warn "node not on PATH; skipped manifest checks"
fi

# 3b. incubator never referenced by manifests
if grep -q incubator .claude-plugin/plugin.json plugin.json 2>/dev/null; then fail "manifests reference incubator/"; else ok "manifests do not reference incubator/"; fi

# 3c. no script installs anything or reaches another machine
if grep -nE '(^|[;&|[:space:]])(curl|wget|ssh|scp|rsync)[[:space:]]|(git|brew|npm|pip3?)[[:space:]]+(push|pull|fetch|clone|install)' $src_files 2>/dev/null | grep -vE "printf|echo|^[^:]+:[0-9]+:[[:space:]]*#" >/dev/null; then
    fail "a script installs something or reaches another machine"
else ok "no script installs anything or reaches another machine"; fi

# 4. governance twins stay identical below their title line
if [ "$(tail -n +2 AGENTS.md)" = "$(tail -n +2 CLAUDE.md)" ]; then ok "AGENTS.md and CLAUDE.md agree"; else fail "AGENTS.md and CLAUDE.md differ below the title"; fi

# 5. line endings: no CR in tracked or new text
cr_scan() {
    { git ls-files 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null; } | while IFS= read -r f; do
        [ -f "$f" ] || continue
        case "$f" in *.png|*.jpg|*.gif) continue ;; esac
        if grep -qI $'\r' -- "$f" 2>/dev/null; then printf '%s\n' "$f"; fi
    done
}
cr_hits="$(cr_scan)"
if [ -n "$cr_hits" ]; then fail "CR line endings in: $(printf '%s' "$cr_hits" | tr '\n' ' ')"; else ok "no CR line endings"; fi

# 5b. no photograph is committed
img_hits="$({ git ls-files 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null; } | grep -iE '\.(heic|heif|tiff?|dng|cr[23]|nef|arw|jpe?g)$' || true)"
[ -z "$img_hits" ] && ok "no photographs in the repository" || fail "image files in the repository: $(printf '%s' "$img_hits" | tr '\n' ' ')"

# 6. tests
ran=0
for t in tests/*.sh; do
    [ -f "$t" ] || continue
    ran=1
    if out="$(bash "$t" 2>&1)"; then
        ok "test $t ($(printf '%s\n' "$out" | grep -c '^ok') assertions)"
        printf '%s\n' "$out" | grep '^skip' | sed 's/^/      /' || true
    else fail "test $t"; printf '%s\n' "$out" | grep -v '^ok' | tail -15 | sed 's/^/      /'; fi
done
[ "$ran" = 1 ] || warn "no tests yet"

# 7. Claude Code validation, tolerating the one known warning
if command -v claude >/dev/null 2>&1; then
    out="$(claude plugin validate . 2>&1 || true)"
    filtered="$(printf '%s\n' "$out" | grep -iE 'warning|error' | grep -v 'CLAUDE.md at the plugin root' || true)"
    if printf '%s' "$out" | grep -qiE '\berror\b'; then fail "claude plugin validate reported errors:"; printf '%s\n' "$out"
    elif [ -n "$filtered" ]; then warn "claude plugin validate warnings:"; printf '%s\n' "$filtered"
    else ok "claude plugin validate"; fi
else
    warn "claude not on PATH; skipped plugin validate"
fi

echo
if [ "$fails" -gt 0 ]; then echo "check: $fails failure(s)"; exit 1; else echo "check: all green"; fi
