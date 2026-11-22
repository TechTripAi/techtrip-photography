# AGENTS.md

Guidance for AI coding agents working in this repository. `CLAUDE.md` and `AGENTS.md` carry
the same text; when you change one, change the other.

## What this is

**`techtrip-photography`** is TechTrip AI's photography plugin: one plugin for the whole
domain, holding photography skills flat under `skills/`. It starts with
`image-transform-tools`, which runs non-destructive image transformations on a folder of
files (first recipe: HEIC or HEIF to TIFF with no further loss), and `photo-expert`, the
tour, which teaches how to use it. Further photography skills and agents are added beside
them over time.

One tree carries an Agent Plugins 1.0.0 manifest at `plugin.json`, a Claude Code manifest at
`.claude-plugin/plugin.json`, and plain `skills/<name>/SKILL.md` folders (Agent Skills
format). Released at 0.1.0; listed in the TechTrip catalog as `techtrip-photography`,
category `photography`. Users install it from there (README "Install").

Install a checkout for development (it loads in place):
```
claude plugin marketplace add /path/to/techtrip-photography
claude plugin install techtrip-photography@techtrip-photography
```

## The design (`docs/decisions/ADR-001`)

- **A transformation reads sources and writes new files.** It never changes, moves or
  deletes a source, never replaces an existing file, and removes only temp files the run
  itself created. The scripts enforce this; the skill text explains it and does not work
  around it.
- **One skill, many recipes.** `image-transform-tools` is the only transformation skill. A
  transformation is a recipe: one script under `scripts/` and one file under `references/`,
  plus a row in the skill's recipe table. A new recipe does not get a new skill.
- **Scripts do the work; the skill does the judgment.** Which folders, whole folder or a
  selection, whether a dry run is worth showing, and how to tell the user what happened are
  the skill's. Decoding, writing, verifying and the safety rules are the scripts'.
- **Preflight advises, never installs.** It names the install command and stops.
- **Selection is by ticking.** `pick.sh` opens a macOS window with one checkbox per source,
  sorted by name, and prints the ticked numbers for `--select`. The window belongs to the
  operating system, not to an AI tool, so it works from any of them. Where no window can
  be opened it exits 5 and the skill falls back to `list.sh` and typed numbers.
- **Questions first, every run.** The skill shows source, destination, whole folder or
  individual files, subfolders and a report in one message, with proposed answers, and
  waits, before any window opens and before anything is written. It does this on every
  run; an answer from an earlier run is never applied silently.
- **Progress is a window.** A chat cannot show a live bar, because the agent speaks only
  when it takes a turn. `--progress-window` opens a small self-closing window that reads
  the progress file; the skill always passes it and sends no progress messages of its own
  while it is open.
- **Verified by default.** An output is compared with its source before it gets its name.
- **macOS for the HEIC recipe.** It decodes with `sips` so the result is what Apple's own
  software shows. Elsewhere preflight exits 4 and nothing runs.

## Layout

- `skills/image-transform-tools/` is self-contained, so it works when only the skill folder
  is linked or copied into another tool:
  - `SKILL.md`: the rules, the recipe table, and the six steps (tools, folders, batch or
    selection, dry run, run, report back).
  - `references/`: `heic-to-tiff.md` (the recipe: what it produces, what is not carried,
    steps, verification, options, Apple Photos export) and `report-format.md` (run output
    lines, statuses, report columns).
  - `scripts/`: `lib/common.sh` (sourced by every script), `preflight.sh`, `list.sh`,
    `pick.sh`, `heic-to-tiff.sh`, `status.sh`, `stop.sh`; `lib/progress-window.js`.
  - `evals/evals.json`: test prompts for skill-creator runs.
- `skills/photo-expert/SKILL.md`: the tour. Teaches, never executes, never restates a
  reference.
- `incubator/<name>/` for unpromoted work. Manifests never see it.
- `docs/` for maintainer documents; `docs/decisions/` for ADRs about this repo.
- `scripts/check.sh` is the health check. Run it before every commit. `tests/*.sh` are run
  by it and by CI on ubuntu, macos and windows; the conversion tests run on macOS only.
- `.claude-plugin/marketplace.json` makes the repo its own single-plugin marketplace for
  development.
- `img/` holds the README banner. No photograph lives in this repository; tests build
  synthetic images under a temp directory.

## How the scripts fit together

- `lib/common.sh` holds what every recipe shares: `list_sources` (the one ordering of source
  files, by name without regard to case, so numbers agree between `list.sh`, `pick.sh` and
  `--select`), `dup_stems` (name
  collisions), `expand_selection`, `img_props`, `unique_path`, `write_new` (refuses to
  replace a file), the run log (`log_row`, `log_count`) and the two report writers.
- Source paths are relative to the source folder. `list_sources <dir> top` reads the folder,
  `all` (`--recursive`) its subfolders too, skipping dot folders; an output keeps its
  relative path under the destination, so a collision is two sources with the same relative
  path apart from the extension. The flag changes the numbering, so `list.sh`, `pick.sh`
  and the recipe get it together.
- A run log is a tab-separated file in the temp directory, one row per selected source:
  number, source, output, status, source bytes, output bytes, width, height, bits, profile,
  note. The summary line and both report formats are produced from it.
- Statuses: `verified`, `converted` (with `--no-verify`), `skipped-exists`,
  `skipped-collision`, `failed`, and `would-convert` in a dry run.
- `heic-to-tiff.sh` per file: `sips` decodes to an uncompressed TIFF in the temp directory;
  `tiffcp -s -r 64 -c lzw:2` rewrites it into a temp name inside the destination (same
  volume, so the final step is a rename); `exiftool -n -tagsfromfile` copies metadata back;
  verification runs; `mv -n` gives it its name. `sips` ignores its own LZW option and writes
  one whole-image tile that some readers refuse, which is why steps two and three exist.
- The temp name in the destination comes from `mktemp` (`.image-transform.XXXXXX`, with
  `.tif` appended for the image). `part_clean` removes exactly those two paths. An `EXIT`
  trap runs it and `work_clean`.
- `pick.sh` builds its rows from `list.sh` and shows them through `osascript` (JavaScript
  for Automation: an `NSAlert` holding a scrolling column of checkboxes). Setting
  `IMAGE_TRANSFORM_PICK_TEST=1,3` builds the window, ticks those rows and returns without
  showing it; the tests use that.
- Progress has three forms from one place (`after_file` in the recipe, helpers in
  `lib/common.sh`): a `[k/n]` counter and time left on each line, which is what captured
  output shows; a bar on stderr, drawn only when stderr is a terminal; and, with
  `--progress-file`, a `key=value` status file rewritten after every file. `status.sh`
  turns that file into one line and exits 0 finished, 7 running, 8 stopped; it treats a
  file that says running whose `pid` is gone as stopped. The time left is elapsed time
  over files really converted, times the files remaining.
- `lib/progress-window.js` (JavaScript for Automation, run with `osascript`) is the
  window: a separate, detached process that only reads the progress file, floats without
  taking the keyboard, and closes a few seconds after the state leaves `running` or the
  run's `pid` is gone. A third argument makes it read once and return its text without
  showing anything; the tests use that.
- Stopping is by `TERM`, from the window's Stop button or `stop.sh <progress file>`; the
  recipe's trap exits 130 and `cleanup` drops the temp file and writes `state=stopped`.
  `INT` cannot be used for this: a shell started in the background ignores it, and that is
  how an agent starts a long run. Ctrl-C in a terminal reaches the same trap.
- The skill runs batches of more than about thirty files in the background, because most
  tools cut a blocking call off after a couple of minutes. It sends no progress messages:
  with no window it says so, waits, and gives the final result. It never restarts a run
  the user stopped.
- Exit codes are the same across scripts: 0 done, 1 something failed or there was nothing
  to do, 2 usage, 3 a tool is missing, 4 operating system not supported. `pick.sh` adds 5,
  no window can be opened here, and 6, cancelled or nothing ticked.

## Exercising a script change

```
S=skills/image-transform-tools/scripts
d=$(mktemp -d); mkdir "$d/src"
sips -s format heic <any image> --out "$d/src/a.HEIC"
bash $S/preflight.sh
bash $S/list.sh "$d/src" "$d/out"
bash $S/pick.sh "$d/src" "$d/out"                  # opens the checkbox window
bash $S/heic-to-tiff.sh "$d/src" "$d/out" --dry-run
bash $S/heic-to-tiff.sh "$d/src" "$d/out" --report md --progress-file auto
bash $S/status.sh <the path printed after "progress:">
bash $S/heic-to-tiff.sh "$d/src" "$d/out"          # converts nothing: all exist
bash tests/heic-to-tiff.sh
```

Never test against a folder of real photographs that has no backup.

## Invariants (check.sh enforces most of these)

- No script changes, moves or deletes a source file, and none replaces an existing file.
  In `skills/*/scripts`: no recursive `rm`, every `mv` is `mv -n`, no `cp`, and `rm` only on
  paths the run created (`$WORK` files, `$PART`, `$LOCK`).
- No script installs anything or reaches another machine.
- Every folder under `skills/` is listed in README "Skills included" and, except
  `photo-expert` itself, mentioned in `photo-expert`.
- The tour skill is `photo-expert`. Its name is unique across TechTrip plugins and its
  description carries "tour" and "how do I use" (the catalog's `docs/packaging.md`).
- `description` is at most 1024 characters (Copilot CLI silently skips longer skills).
- SKILL.md frontmatter uses only Agent Skills spec keys plus the Claude Code extensions
  `argument-hint` and `disable-model-invocation`. Both skills stay model-invocable: plain
  language such as "convert these HEIC files" must reach `image-transform-tools`.
- Skill text names no tool of any one harness. Where a harness feature could help (a
  multiple-choice picker), the text says "if your tool has one".
- Every script and reference a SKILL.md names exists.
- A recipe is described once, in its reference file. `SKILL.md` and `photo-expert` point
  there.
- `version` and `description` agree between `plugin.json` and `.claude-plugin/plugin.json`,
  the entry in `.claude-plugin/marketplace.json` carries the same version, and the
  CHANGELOG's first `## [x.y.z]` heading matches.
- Scripts: `#!/usr/bin/env bash`, `set -eu`, no arrays (macOS bash 3.2), POSIX tools,
  `SCRIPT_DIR` via `pwd -P`, a usage comment at the top with exit codes. No `case` inside
  `$( )` (bash 3.2 cannot parse it); use a function.
- File names with spaces work everywhere. Loops read paths line by line from a file on
  descriptor 3, so commands inside the loop keep their own standard input.
- No personal names, folder names or photographs inside a skill or a test.
- `AGENTS.md` and `CLAUDE.md` are identical below the title line.

## Not built yet

Other recipes (other formats, resizing, metadata-only work), a decoder path for Linux and
Windows, and agents. Adding a recipe is described in `docs/conventions.md`.

## Validate

```
bash scripts/check.sh               # needs node on PATH (reads the manifests); skips plugin validate if claude is absent
claude plugin validate .            # one known warning: root CLAUDE.md is not loaded as context
claude --plugin-dir .               # then talk to it with a scratch folder of images
```

## Release

Bump `version` in both manifests and in the entry in `.claude-plugin/marketplace.json`, add
the CHANGELOG section, run `check.sh`, commit locally with a plain message (no attribution
lines). The owner pushes. After every release here, the entry's `version` in the
TechTrip-AI-plugins catalog is set to the same string.

## Meta

- License: **FSL-1.1-MIT** (`LICENSE.md`). Copyright 2026 Terry Trippany (Try AI Solutions).
- Owner/repo: `TechTripAi/techtrip-photography` (public).
- Packaging, naming and release rules for every TechTrip plugin:
  https://github.com/TechTripAi/TechTrip-AI-plugins/blob/main/docs/packaging.md
  (the catalog's `docs/packaging.md`). Follow it; do not restate it here.
