# Changelog

All notable changes to `techtrip-photography` are documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [0.1.0] - 2026-11-22

First version. In development; not yet listed in the catalog.

### Added
- **`image-transform-tools`**, the skill for image transformations. It settles the source
  and destination folders, checks the tools, converts a whole folder or the files ticked
  in a checkbox list, offers a dry run, and reports how each file went.
- **Recipe: HEIC or HEIF to TIFF with no further loss** (`heic-to-tiff.sh`). Decodes with
  macOS's own decoder, writes LZW-compressed TIFF in strips at the source's bit depth with
  its colour profile, and copies capture metadata across unrounded. `--compression none`
  writes it uncompressed.
- **Verification**, on by default: each output is decoded and compared with its source
  pixel for pixel before it is given its name; its compression and capture metadata are
  checked too. A file whose pixels differ is not kept.
- **Safety rules, enforced by the scripts and checked by the tests:** a source is never
  changed, moved or deleted; an existing file is never replaced; two sources that would
  produce the same output name are both skipped; only temp files the run created are
  removed.
- `preflight.sh` reports each required tool as present or missing with its install command,
  and installs nothing. `list.sh` numbers the source files, sorted by name, with size, pixels,
  bit depth, colour profile and status.
- `pick.sh` opens a window with one checkbox per source file and returns the ticked ones.
  It is a macOS window, so it works from any AI tool; where none can be opened the skill
  falls back to the numbered list.
- The skill asks its questions before anything opens or is written, on every run:
  destination, whole folder or individual files, subfolders, a report.
- `--recursive` reads subfolders too and mirrors them in the destination.
- `--progress-window` shows a small self-closing window with a progress bar, the count,
  the time left and a Stop button. The skill always uses it.
- Stopping: the Stop button, `stop.sh` or Ctrl-C ends a run early, keeps what is done and
  leaves nothing half-written.
- Progress: every file's line has a counter and the time left; in a terminal a bar is
  drawn; `--progress-file` keeps a status file that `status.sh` reads, and the skill runs
  large batches in the background and reports from it. An interrupted run carries on when
  the same command is run again.
- Reports: `--report md` or `--report csv` writes one row per file. A report never replaces
  an earlier one.
- **`photo-expert`**, the tour: a menu that teaches the above and hands over the prompts to
  type.
- `references/heic-to-tiff.md` and `references/report-format.md`,
  `tests/heic-to-tiff.sh`, `docs/decisions/ADR-001`.
