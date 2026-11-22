---
name: photo-expert
description: "Teaching guide and tour for the techtrip-photography plugin: how to convert HEIC or HEIF photos to TIFF with no further loss, check that the needed tools are installed, convert a whole folder or tick files in a checkbox list, try a dry run first, read the result and the report, what is and is not carried into a TIFF (HDR gain map, depth data, Live Photo video), why edits on HEIC files can shift between programs, how to export unmodified originals from Apple Photos, what the plugin will never do to your files, and how to run the scripts from a terminal. Hands you the exact prompts to type; it never converts, lists or changes files for you. Menu-style and re-runnable. Triggers on: photo tour, photography tour, photo expert, how do I use image-transform-tools, how do I use the image transform tools, how do I convert my HEIC files, how does the photography plugin work, image transform help, walk me through converting photos. Not for study, stories, sessions or second brains; those are other plugins' tours."
---

# photo-expert: how to use the photography tools

You are a teacher of the tool, not a doer. Explain how `image-transform-tools` works and
hand the user the exact prompts to type. Do not run the scripts, list their folders or
convert anything yourself; for each of those, give the prompt and let them run it.

Rules for this tour:

- Show the menu, wait for a choice, explain that section, then offer the menu again.
- Every block is one of two kinds, and its first line says which: **Prompt: type into your
  AI tool**, or **Shell: run in your terminal**.
- Use `<placeholders>`, never invented folder or file names.
- This is a conversation. Never tell the user to type exit, quit or stop.
- Do not restate a reference file. Point at it by name.

## Menu

1. What this is, in one minute
2. Before you start: the tools it needs
3. Converting a whole folder
4. Ticking the files you want
5. Trying it first: the dry run
6. Reading the result, and reports
7. What "no loss" means, and what stays behind
8. What it will never do to your files
9. Getting originals out of Apple Photos
10. Running the scripts yourself
11. Install and update

## Section 1: what this is

One working skill, `image-transform-tools`. You tell it in plain words which folder of
images to transform and where the results should go. It has one transformation so far:
HEIC or HEIF photos, such as iPhone photos, to TIFF files that hold exactly the pixels the
original decodes to, with the capture date, location, lens data and colour profile kept.

People want this when an editor handles HEIC badly: the picture looks right, then looks
different when it is reopened or sent to another program. TIFF files do not do that.

It runs on macOS, because it uses the decoder macOS itself uses.

## Section 2: the tools it needs

Three programs do the work: `sips`, which is part of macOS, and `tiffcp` and `exiftool`,
which most people install with Homebrew. The skill checks for them before it converts and
tells you the command for anything missing. It never installs anything itself.

**Prompt: type into your AI tool**
```
check that I have the tools to convert HEIC files
```

Expect: a short list, each line `ok` or `missing`, and for a missing tool the command that
installs it.

**Shell: run in your terminal** (only if something was missing)
```
brew install libtiff exiftool
```

## Section 3: a whole folder

**Prompt: type into your AI tool**
```
convert the HEIC files in <source folder> to TIFF in <destination folder>
```

It asks its questions first, all at once, every time you convert: where the results go
(it offers a `tif` folder beside the source), whether you want the whole folder or
individual files, whether to include subfolders, and whether you want a report. What you
already said is filled in for you to confirm. Nothing opens and nothing is written until
you have answered, and answers from an earlier conversion are never reused without asking.

Then expect one line per file as it works and a summary: how many were converted and
verified, how many were skipped and why. A large photo takes about two seconds, so sixty
photos take around two minutes. A small progress window opens with a bar, the count and
about how long is left, and closes itself when the work is done. Press Stop in that window
to stop early, or say "stop the conversion"; what is already converted is kept. You can
also ask at any time: "how far along is the conversion?"

Where no window can be opened, such as over a remote connection, there is no progress
display: it tells you so, works, and reports when it is done.

If a long run is cut off, ask for the same conversion again. Finished photos are skipped,
so it carries on from where it stopped.

With subfolders included, each TIFF goes in the same subfolder of the destination.

## Section 4: ticking the files you want

**Prompt: type into your AI tool**
```
show me the HEIC files in <source folder> and let me pick which to convert
```

Expect: a window on your screen listing the files sorted by name, each with a checkbox,
its size, pixel dimensions and a status. Tick the ones you want and press "Use ticked
files". Nothing is converted if you press "Cancel".

If no window can be opened, for example over a remote connection, you get a numbered list
in the chat instead and answer with numbers and ranges, such as `1-5, 9`. You can also ask
for that on purpose: "list them and I'll give you numbers".

The status says `new` for a file that would be converted, `exists` when the
destination already has a TIFF of that name, and `collision` when two sources would become
the same file.

## Section 5: the dry run

A dry run says what would happen and writes nothing, not even the destination folder. The
skill does one by itself for a large batch or a destination that already has files in it.
You can ask for one at any time:

**Prompt: type into your AI tool**
```
what would be converted from <source folder> to <destination folder>? don't convert yet
```

## Section 6: the result, and reports

Each file ends up as one of: verified, already existed, in a name collision, or failed with
a reason. Verified means the new TIFF was decoded and compared with the original, pixel for
pixel, and its capture data was compared too.

For a record you can keep:

**Prompt: type into your AI tool**
```
convert <source folder> to TIFF in <destination folder> and write a report
```

Expect: a Markdown file in the destination folder, named with the date and time, with one
row per file. Ask for "a CSV report" to get a spreadsheet-friendly one. A report never
replaces an earlier report. The columns are described in `references/report-format.md`,
inside the `image-transform-tools` skill.

## Section 7: what "no loss" means

A HEIC is already compressed when the camera writes it. Converting adds no further loss; it
cannot restore what the camera discarded. The TIFF will be several times larger than the
HEIC, because it stores every pixel exactly.

A phone HEIC also carries extras that a TIFF cannot: the HDR gain map, which is the extra
brightness on HDR screens; depth data for portrait effects; and, for a Live Photo, a video
beside it. The TIFF is the standard image without those. Your HEIC keeps them, and it is
still where it was.

`references/heic-to-tiff.md`, inside the skill, has the full account, including why an
editor's view of a HEIC can change between sessions and how each output is verified.

**Prompt: type into your AI tool**
```
why do my HEIC edits look different when I reopen them?
```

## Section 8: what it will never do

- Change, rename, move or delete an original.
- Replace a file that already exists. If a TIFF of that name is there, that photo is
  skipped and you are told.
- Pick a winner when two originals would become the same file. Both are skipped.
- Remove anything except its own temporary files.
- Install software, or send anything off your machine.

If you want a TIFF made again, move the old one yourself and convert again.

## Section 9: originals from Apple Photos

To convert what the camera recorded, export it unchanged. In Photos: select the photos,
then File, Export, Export Unmodified Original. They come out as HEIC because that is what
the phone wrote; that export offers no other format.

Put the exported files in a folder your editors are not pointed at, and convert from there.
Some editors write their settings into the HEIC file itself, and after that the file is no
longer the original.

## Section 10: the scripts

They are in the `scripts` folder of the `image-transform-tools` skill. The first three only
read; the last writes nothing because of `--dry-run`.

**Shell: run in your terminal**
```
bash <skill folder>/scripts/preflight.sh
bash <skill folder>/scripts/list.sh "<source folder>" "<destination folder>"
bash <skill folder>/scripts/pick.sh "<source folder>" "<destination folder>"
bash <skill folder>/scripts/heic-to-tiff.sh "<source folder>" "<destination folder>" --dry-run
```

Expect: the tool check; the numbered list; the checkbox window, which prints the numbers
of what you ticked; what a conversion would do.

To convert, run the last line without `--dry-run`. Add `--select "1-5,9"` to convert some,
`--recursive` for subfolders, `--progress-window` for the progress window, and
`--report md` for a report. In a terminal you get a progress bar with the time left, and
Ctrl-C stops the run cleanly. Every option is in `references/heic-to-tiff.md`.

## Section 11: install and update

The plugin is installed from the TechTrip-AI-plugins catalog:

**Prompt: type into Claude Code**
```
/plugin marketplace add TechTripAi/TechTrip-AI-plugins
/plugin install techtrip-photography@TechTrip-AI-plugins
```

Update with `/plugin update techtrip-photography@TechTrip-AI-plugins`, then start a new
session. The README in the plugin repository has the install and update commands for
Copilot CLI, Cursor, Codex, Gemini CLI and other tools.
