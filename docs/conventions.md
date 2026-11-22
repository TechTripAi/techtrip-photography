# Conventions

Maintainer rules for this repository. `CLAUDE.md` and `AGENTS.md` summarise them for agents;
this file is the long form. Packaging, naming and release rules shared by every TechTrip
plugin are in the catalog's `docs/packaging.md` and are not repeated here.

## Layout
- `skills/<name>/SKILL.md` plus optional `scripts/`, `references/`, `evals/`. Flat; no
  bucket folders. The skill's `name` equals its directory name.
- A skill is self-contained: its scripts and references live inside its own folder, so it
  works when only that folder is linked or copied into another tool.
- `incubator/<name>/` for unpromoted skills. Never referenced by manifests.
- `docs/` for maintainer documents and `docs/decisions/` for ADRs about this repo.
- `tests/*.sh` are standalone bash, each building its images under `mktemp -d`. They delete
  nothing; the OS temp cleaner owns what they leave. No photograph is committed.
- `plugin.json` (Agent Plugins 1.0.0) and `.claude-plugin/plugin.json` (Claude Code) carry
  the same `version` and `description`.

## The safety rules
Every transformation keeps these, and `scripts/check.sh` and the tests hold them in place:

1. A source file is never changed, renamed, moved or deleted.
2. An existing file is never replaced. The source is skipped and reported.
3. Two sources that would produce the same output name are both skipped and reported.
4. The only files removed are temp files the run created, by exact path. No recursive
   delete anywhere.
5. Nothing is installed and nothing leaves the machine.

In script terms: no `rm -r`; `rm -f` only on `$WORK` files, `$PART` and `$LOCK`; every `mv`
is `mv -n` followed by a check that the temp file is gone; no `cp`; files are created with
`write_new` or under a `mktemp` name.

## Adding a recipe
A recipe is one transformation. To add one:

1. Write `skills/image-transform-tools/scripts/<from>-to-<to>.sh`. Source `lib/common.sh`.
   Take `<source-dir> <dest-dir>` and the shared options (`--select`, `--recursive`,
   `--dry-run`, `--no-verify`, `--progress-file`, `--report`, `--report-dir`). Use `list_sources` for the file order, the
   run log for results, `progress_write` and the bar helpers after every file, and the
   shared statuses and exit codes.
2. Build each output under a `mktemp` name inside the destination, verify it there, then
   `mv -n` it into place.
3. Add its tools to `needs_for` in `preflight.sh` and its extensions to `list.sh`.
4. Describe it once in `references/<from>-to-<to>.md`: what it produces, what it does not
   carry, steps and why, verification, options.
5. Add a row to the recipe table in `SKILL.md` and a section or line in `photo-expert`.
6. Add `tests/<from>-to-<to>.sh` with the safety assertions from `tests/heic-to-tiff.sh`:
   sources byte for byte unchanged, an existing output left alone, a collision skipped,
   nothing left behind.
7. README, CHANGELOG, `bash scripts/check.sh`.

A recipe that cannot verify its output against its source says so in its reference file.

## Frontmatter
- `name`, `description` (at most 1024 characters; Copilot CLI silently skips longer ones).
- Both skills are model-invoked and keep a rich trigger description so plain language
  reaches them.
- `argument-hint` on anything that takes an argument.

## Writing skill text
- The user never has to name a script or a flag. Skill text is written so the agent works
  out the folders and the kind of run from what was said.
- No tool of any one harness is named. Where a harness feature could help, write "if your
  tool has one".
- Explain why a rule exists. The safety rules are there because the files are irreplaceable.
- Every question is asked before a window opens or a file is written, in one message, on
  every run. What the user said is offered back for confirmation; nothing from an earlier
  run is applied silently.
- Keep `SKILL.md` short. A recipe's detail goes in `references/`, read only when needed.
- Describe a recipe or a format once. Other files point at the reference by name.
- Report results as they are: counts, names, reasons. Never round a partial result up.
- No personal names, folder names or camera serials. Use `<placeholders>`.

## Scripts
- `#!/usr/bin/env bash`, `set -eu`, no arrays (macOS ships bash 3.2), POSIX tools plus the
  ones a recipe declares in `preflight.sh`.
- `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"`, then source
  `lib/common.sh`.
- Loop over paths with `while IFS= read -r f <&3; do ...; done 3< "$WORK/list"`, so spaces
  in names work and commands inside the loop keep standard input.
- No `case` statement inside a `$( )` command substitution: bash 3.2 cannot parse it. Put
  it in a function and call that.
- A usage comment at the top of every script: what it does, usage, exit codes.
- Exit codes: 0 done, 1 something failed or nothing to do, 2 usage, 3 tool missing, 4
  operating system not supported.

## Release
1. Bump `version` in `plugin.json`, `.claude-plugin/plugin.json` and the entry in
   `.claude-plugin/marketplace.json`.
2. Add the `## [x.y.z] - YYYY-MM-DD` section to `CHANGELOG.md`.
3. `bash scripts/check.sh`.
4. Commit locally with a plain message. The owner pushes.
5. First release: add the entry to TechTrip-AI-plugins, a row to its README table and a row
   to the tour table in its `docs/packaging.md`, after the repository is public and pushed.
   Later releases: set the entry's `version` to the same string. The catalog's check
   compares it with the pushed manifest, so it is done after the owner pushes.
