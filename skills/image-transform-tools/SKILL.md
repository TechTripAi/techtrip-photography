---
name: image-transform-tools
description: "Non-destructive image transformations on a folder of image files. First recipe: HEIC or HEIF (iPhone photos, Apple Photos exports) to TIFF with no further loss, pixel-for-pixel what the original decodes to, with capture date, location, lens data and colour profile kept. Converts a whole folder or only the files the user ticks in a checkbox list, checks the needed tools first, offers a dry run, verifies every output, and can write a report. It never changes, moves or deletes an original and never replaces an existing file. macOS. Use it whenever the user wants to convert, transform or batch-process image files: HEIC to TIFF, iPhone photos for Lightroom, Photoshop, Topaz or another editor, edits on HEIC files that shift or change colour when reopened, a lossless copy of a folder of photos, or a report of what was converted. Triggers on: convert these HEIC files, heic to tiff, turn my iPhone photos into TIFFs, batch convert this folder, let me pick which photos to convert, what would be converted."
argument-hint: "[<source folder>] [<destination folder>] [what to convert]"
---

# image-transform-tools

You run image transformations for someone who cares about their originals. A transformation
reads source files and writes new files beside or apart from them. The scripts do the work
and keep the safety rules; your part is to work out what the user wants, show them what will
happen, run it, and tell them plainly how it went.

The scripts are in the `scripts/` directory next to this SKILL.md and the detail is in
`references/`. Resolve those paths from wherever you read this file; below, `<scripts>` means
that directory.

## What holds for every transformation

These are the reasons someone can point this at a folder of irreplaceable photographs:

- **Originals are read, never touched.** No source file is changed, renamed, moved or deleted.
- **Nothing is replaced.** If a file with the output's name already exists, that source is
  skipped and reported. Two sources that would produce the same output name are both skipped,
  so neither silently wins.
- **Only temp files are removed**, and only ones the run itself created.

The scripts enforce all three. Do not work around them: no deleting or renaming an existing
output so a conversion can "go through", no cleaning up a folder for the user, no converting
with other commands when a script declines. If the user wants an existing output redone,
tell them which file is in the way and let them move it.

## Recipes

| Recipe | Script | Detail |
|---|---|---|
| HEIC or HEIF to TIFF, no further loss | `<scripts>/heic-to-tiff.sh` | `references/heic-to-tiff.md` |

One recipe for now. When the user asks for a transformation that is not listed, say it is
not available yet rather than improvising one with other tools: a hand-rolled conversion
would not carry the guarantees above.

## 1. Check the tools

Run `bash <scripts>/preflight.sh`. It lists each requirement as `ok` or `missing`.

- Exit 0: ready.
- Exit 3: a tool is missing. Show the user the install command it printed and stop. Do not
  install anything yourself; what goes on their machine is their decision.
- Exit 4: the recipe needs macOS and this is not macOS. Say so and stop.

## 2. Ask everything first, every run

Settle every choice in the conversation before anything opens on the user's screen and
before anything is written. A window that appears while questions are still open is
confusing, and a question asked after the user has ticked forty files may undo their work.

Do this at the start of every run, including a second run in the same conversation. Show
all five choices in one message as a short numbered list, each with the answer you propose,
and wait for the user to confirm or change them. If your tool has a form for asking several
questions at once, use it.

1. **Source folder.** No default.
2. **Destination folder.** Default: a `tif` folder beside the source folder. The source
   folder itself is allowed if they ask for it.
3. **Whole folder, or individual files.** Always the user's call; never assume it. Naming a
   folder is not the same as saying "all of it".
4. **Subfolders.** Default: this folder only. Leave the line out only when the source folder
   has no subfolders. If included, each output goes in the same subfolder of the destination.
5. **A report file.** Default: none. Markdown or CSV.

Where the proposed answers come from: what the user said in this request first, then the
defaults above. Answers from an earlier run are not carried over silently. A folder, a
subfolder choice or a selection that was right last time may be wrong this time, and the
user cannot see what you assumed. You may offer last time's answer as the proposal, marked
as such ("same as last time: ..."), and it still needs their yes.

When they have answered, say back in one line what you are about to do, including that a
small progress window will open, then carry on.

## 3. Whole folder, or chosen files

- **Whole folder:** go to step 4.
- **Individual files:** open the checkbox window. Tell them first that a window is
  about to open on their screen, then run
  `bash <scripts>/pick.sh "<source>" "<destination>"` (add `--recursive` if subfolders are
  included). It lists the files sorted by name,
  one checkbox each, with size, pixels and status, and waits until they press "Use ticked
  files" or "Cancel". The call does not return while the window is open, so give it a long
  timeout if your tool lets you set one, and do not run anything else meanwhile.
  - Exit 0: it printed the ticked files' numbers, such as `1,3,7`. Pass that to `--select`.
  - Exit 6: they cancelled or ticked nothing. Convert nothing; ask what they would like.
  - Exit 5: no window can be opened here. Fall back to numbers: run
    `bash <scripts>/list.sh "<source>" "<destination>"` (with `--recursive` if subfolders
    are included), show the list as it is, and ask which numbers. They can answer with numbers and ranges (`1-5, 9`).
The window is the way to choose; do not replace it with a typed list because that is
quicker for you. Use the numbered list only on exit 5 or when the user asks to type numbers.

Files are numbered in name order, the same in `pick.sh`, `list.sh` and `--select`. If files
were added or removed since they chose, let them choose again. `--recursive` changes the
numbering, so give it to every script in a run or to none.

## 4. Show what will happen when it is worth it

Run the recipe with `--dry-run` first, and show the result, when any of these is true: more
than about twenty files; the destination already has files in it; the list showed `exists`
or `collision`; or the user asked what would happen. For a handful of new files into an
empty folder, skip it and convert.

A dry run writes nothing, not even the destination folder.

## 5. Run it

```
bash <scripts>/heic-to-tiff.sh "<source>" "<destination>" --progress-window [--recursive] [--select "<numbers>"] [--report md|csv]
```

Always add `--progress-window`. It opens a small window with a bar, the count and about how
long is left and a Stop button; it floats above other windows, does not take the keyboard,
and closes itself a few seconds after the run ends. This is how the user sees progress: a chat cannot show a
live bar, because you can only speak when you take a turn. The script prints
`progress window: open`, or `progress window: not available here` where there is no screen.

Allow about two seconds per large photo, and tell the user roughly how long the batch will
take before you start it.

**More than about thirty files: run it in the background.** Most tools cut a blocking call
off after a couple of minutes. Start the command in the background with its output sent to
a file in the temp folder, so you can read the per-file lines afterwards. Its first lines
are `progress: <path>` and the progress window line.

- Do not send progress messages of your own. With the window open it is already doing
  that, and a stale "3 of 61" in the chat is worse than nothing. With no window, say before
  you start that there will be no progress display and that you will report when it is
  done; then wait, and give the final result.
- Whenever the user asks how far along it is, run `bash <scripts>/status.sh "<path>"` and
  tell them. It exits 7 while running, 0 when finished, 8 if the run stopped early.

**Stopping.** The user can stop a run with the window's Stop button, or by asking you:
run `bash <scripts>/stop.sh "<path>"`. In a terminal, Ctrl-C does the same. A stopped run
exits 130; it drops the file it was on, keeps every file already done, and leaves nothing
half-written. Tell the user how far it got and that asking for the same conversion again
carries on from there. Do not start it again yourself: they stopped it on purpose.

If your tool cannot run a command in the background, give the call the longest timeout it
allows.

A run that was cut off by a timeout, not stopped by the user, is safe to start again with
the same command: finished files are skipped. Say so and carry on; do not clean anything
up by hand.

Options, statuses and what verification covers are in `references/heic-to-tiff.md`. Leave
verification on unless the user asks for speed over certainty and understands the trade.

Exit 0 means nothing failed. Exit 1 means at least one file failed; the others were still
converted.

## 6. Tell them how it went

Report from the summary line and the per-file lines, in plain words:

- how many were converted and verified, and where they are
- which were skipped because an output already existed, by name
- which were skipped for a name collision, and which names collide
- which failed, with the reason the script gave
- any `note:` on a converted file, such as a metadata difference

Do not round "verified 58, failed 2" up to "done". If something failed or was skipped, say
what the user can do about it. Say that the originals are untouched.

If they decide afterwards that they want a report after all, run again with `--report md`:
nothing is reconverted, because every output now exists. The report's
columns and statuses are described in `references/report-format.md`. A report is given a
name with the date and time and never replaces an earlier one.

## Questions that come up

Read `references/heic-to-tiff.md` before answering questions about what "no loss" means
here, why the TIFFs are so much larger, what happens to HDR, why an editor's view of a HEIC
can change between sessions, or how to get originals out of Apple Photos. Say what is known
and what is only likely; do not present a likely cause as a proven one.
