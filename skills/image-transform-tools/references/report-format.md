# Run output and report files

## The lines a run prints

One line per selected file, then a blank line and one summary line. Each file's line
starts with a counter, `[12/61]`, then one of the words below. A converted file's line ends
with about how long the rest will take. Run in a terminal, a bar is drawn under the lines
as well.

| After the counter | Meaning |
|---|---|
| `verified` | Converted, and the output matched its source |
| `converted` | Converted with `--no-verify` |
| `exists` | A file with the output's name was already there; the source was skipped and the existing file left as it is |
| `collision` | Another source would produce the same output name; neither was converted |
| `failed` | Nothing was kept for this file; the reason follows in brackets |
| `would convert` | Dry run only |

A converted line may end with `note:` and a remark, such as a metadata difference.

## The progress window

With `--progress-window`, a small window shows a bar, how many files are done, about how
long is left, the counts so far and the file being worked on. It floats above other
windows without taking the keyboard, and closes itself a few seconds after the run
finishes or stops. It only reads the progress file described next; losing the window does
not affect the run.

Its Stop button asks the run to stop. So does `scripts/stop.sh <progress file>`, and so
does Ctrl-C in a terminal the run was started from. A stopped run drops the file it was
working on, keeps every file already done, leaves nothing half-written and exits 130. The
same command run again carries on from there.

## The progress file

With `--progress-file`, a run keeps a small text file up to date after every file, so its
progress can be read while it is still going. `auto` makes the file in the temp folder and
prints `progress: <path>` as the run's first line; a path of your own is used as given and
refused if anything is already there.

Read it with `scripts/status.sh <path>`, which prints one line and exits 0 when the run has
finished, 7 while it is running and 8 if it stopped before finishing. The file itself is
`key=value` lines: `state` (`running`, `done` or `stopped`), `done`, `total`,
`elapsed_seconds`, `eta_seconds`, `current`, a count for each status, and `updated`.

## Report files

Written only when `--report md` or `--report csv` is given, and never on a dry run. The
name is `image-transform-report-<date>-<time>` with the extension of the format. If a file
of that name exists, `-2`, `-3` and so on is added; a report never replaces another.

Both formats have one row per selected file with these columns:

| Column | Content |
|---|---|
| `n` / `#` | The file's number, as `list.sh` shows it |
| source | Markdown: the file name. CSV: the full path |
| output | The file written, empty when none was |
| status | `verified`, `converted`, `skipped-exists`, `skipped-collision` or `failed` |
| source size, output size | Markdown: readable. CSV: bytes |
| pixels | Width and height (two columns in CSV) |
| bits | Bits per channel of the source |
| profile | Colour profile name of the source |
| note | The reason for a skip or failure, or a remark on a converted file |

The Markdown report opens with the source folder, the destination folder, the settings and
the time of the run, and ends with totals. It reads in any Markdown tool.
