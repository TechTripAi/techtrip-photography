# techtrip-photography

<p align="center">
  <img src="img/FellowshipOfTheAgents-Photography.png" alt="techtrip-photography: non-destructive image tools for photographers, from TechTrip AI" width="100%" />
</p>

> **V1: macOS only.** The conversion uses the decoder built into macOS. On Linux and
> Windows the skills install and report that conversion is not supported there yet.

> **Status: first release, under test (version 0.1.0).** It works and is installable, but
> expect rough edges and changes while it is being tried on real photographs. Reports of
> anything that goes wrong are welcome as issues on this repository.

**TechTrip AI's photography skills, one plugin for the whole domain.** It starts with image
transformations that are safe to point at a folder of irreplaceable photographs: they read
your originals, write new files, and never change, delete or replace anything. The first
transformation turns HEIC photos into TIFF files with no further loss. It is installed from
the [TechTrip-AI-plugins](https://github.com/TechTripAi/TechTrip-AI-plugins) catalog.

## Install

```
/plugin marketplace add TechTripAi/TechTrip-AI-plugins
/plugin install techtrip-photography@TechTrip-AI-plugins
/techtrip-photography:photo-expert
```

The first line registers the TechTrip catalog, the second installs the plugin, the third
starts its tour. For Copilot
CLI, Cursor, Codex, Gemini CLI and other tools, see "Other AI tools" below.

## Requirements

- **macOS.** V1 runs on macOS only. It decodes with `sips`, which is part of macOS, so the
  result matches what Apple Photos and Preview show.
- **`tiffcp` and `tiffinfo`:** `brew install libtiff`
- **`exiftool`:** `brew install exiftool`

The skill checks for these before it converts and tells you what is missing; it does not
install them.

## How it works

You say which folder to work on. The skill asks its questions up front, all at once, every
time: where the results go, the whole folder or individual files, whether to include
subfolders, and whether you want a report. What you already said is filled in for you to
confirm; answers from an earlier run are never reused without asking. Nothing opens on your
screen and nothing is written until you have answered. It then checks that
the tools it needs are installed, shows you what will happen when the batch is large or the
destination is not empty, converts, checks every new file against its original, and tells
you how each file went.

**HEIC to TIFF.** iPhone photos and other HEIC or HEIF files become TIFF files that hold
exactly the pixels the original decodes to. Capture date, location, camera, lens and
exposure data are carried across, and so is the colour profile. Compression is LZW, which is
lossless. This is for editors that handle HEIC badly, where a picture looks right and then
looks different when it is reopened or passed to another program.

**A whole folder, or the files you tick.** Convert everything in a folder, or ask to
choose: a window opens listing the files sorted by name, each with a checkbox, and only the
ones you tick are converted. Where no window can be opened, you get a numbered list and
answer with numbers such as `1-5, 9`.

**Subfolders if you want them.** By default only the folder you name is read. Include its
subfolders and each TIFF goes in the same subfolder of the destination.

**Every output is verified.** Each new TIFF is decoded and compared with its original,
pixel for pixel, before it is given its name. A file that does not match is not kept.

**Progress you can see, and a Stop button.** A small window shows a progress bar, how many
photos are done and about how long is left, and closes itself at the end. Stop ends the
run early and keeps everything already converted; so does Ctrl-C in a terminal. Where no
window can be opened, the skill works quietly and reports when it is done. Every file's line in the output
carries the same counter, and in a terminal you get a bar there too. A run that is cut off carries
on where it stopped when you ask again, because finished photos are skipped.

**A dry run on request.** It says what would be converted, what would be skipped and why,
and writes nothing.

**A report if you want one.** A Markdown or CSV file with one row per photo: what was
written, sizes, dimensions, colour profile and the result.

You talk in plain words:

- "convert the HEIC files in ~/Pictures/export to TIFF"
- "show me the HEIC files in this folder and let me tick which to convert"
- "what would be converted? don't convert yet"
- "convert that folder and write a report"
- "check that I have the tools to convert HEIC files"
- "why do my HEIC edits look different when I reopen them?"

## What it will never do

- Change, rename, move or delete an original.
- Replace a file that already exists. If a TIFF of that name is there, that photo is
  skipped and reported.
- Pick a winner when two originals would become the same file. Both are skipped and
  reported.
- Remove anything except temporary files it created during the run.
- Install software, or send anything off your machine.

The scripts enforce these, and the tests check them.

## What a TIFF does not carry

A HEIC is already compressed when the camera writes it; converting adds no further loss and
cannot restore what the camera discarded. A phone HEIC also holds extras that a TIFF cannot:
the HDR gain map, depth data for portrait effects and, for a Live Photo, a video beside it.
The TIFF is the standard image without those. Your HEIC keeps them and stays where it was.
A TIFF is typically eight to ten times the size of its HEIC.

## Skills included

- **`image-transform-tools`**: everything above. Works out the folders and whether you want
  the whole folder or a selection, checks the tools, converts, verifies and reports.
  Try "convert the HEIC files in this folder to TIFF", or `/image-transform-tools`.
- **`photo-expert`**: a menu-style tour that hands you the prompts to type and never runs
  anything. Try "give me the photo tour", or `/techtrip-photography:photo-expert`.

## Other AI tools

The two folders under `skills/` are plain Agent Skills, and `image-transform-tools` carries
its own scripts and references, so it works in any tool that reads a skills folder. One
command installs both skills for Cursor, Codex, Gemini CLI and other tools:

```
npx skills add TechTripAi/techtrip-photography -g
```

It asks which tools to install for. `-g` installs for your user account; leave it off to
install into the current project only. Requires Node.js. `npx skills update -g` picks up
later releases.

To install for one tool only:

- **Gemini CLI only.** Gemini CLI installs from the repository itself, into
  `~/.gemini/skills`, which no other tool reads:

  ```
  gemini skills install https://github.com/TechTripAi/techtrip-photography.git --path skills
  ```

  Add `--scope workspace` to install into the current project only. Requires Gemini CLI
  0.68.0 or later.

- **Cursor only.** Name the tool with `-a`:

  ```
  npx skills add TechTripAi/techtrip-photography -g -a cursor
  ```

  With `-g` the skills go to `~/.agents/skills`, a shared folder that other tools also
  read. To keep them to Cursor in one project, leave `-g` off and run the command in that
  project.

Gemini CLI uses its own authentication, which this plugin does not configure. Set it up
with a Gemini API key on a project that has billing enabled. See
[Google's API key instructions](https://ai.google.dev/gemini-api/docs/api-key).

Do not keep a second copy of a skill in another skills directory; two copies leave the bare
name pointing at whichever loaded first.

## What it writes

Only the files you ask for, in the destination folder you name: one `.tif` per converted
photo and, when you ask for one, a report file. While a file is being converted it has a
temporary name starting with `.image-transform` in the destination folder; that is renamed
or removed before the run ends. Scratch files go in the system temp folder and are removed
at the end of the run. Nothing is written to the source folder unless you name it as the
destination. Nothing leaves your machine.

## Updating

Update the plugin the way you installed it:

| Installed with | Update with |
|---|---|
| Claude Code, from the catalog | `/plugin update techtrip-photography@TechTrip-AI-plugins`, then `/reload-plugins` or a new session |
| Copilot CLI, from the catalog | `copilot plugin marketplace update`, then `copilot plugin update techtrip-photography` |
| `npx skills add` (Cursor, Codex, Gemini CLI and others) | `npx skills update -g` |
| A clone | `git pull` |

## Developing

To work on the plugin, register a clone as its own marketplace. It then loads in place:
edits apply at the next session start or after `/reload-plugins`, with no version bump. Do
not keep this and the catalog install side by side.

```
git clone https://github.com/TechTripAi/techtrip-photography.git
claude plugin marketplace add /path/to/techtrip-photography
claude plugin install techtrip-photography@techtrip-photography
```

```
bash scripts/check.sh      # syntax, frontmatter, versions, safety rules, tests
claude plugin validate .   # Claude Code's own manifest check
```

To try a clone in another tool, link its skill folders in place of the `npx` install:
`gemini skills link /path/to/techtrip-photography/skills` for Gemini CLI (0.68.0 or later),
or symlink each folder under `skills/` into the tool's skills directory, such as
`~/.cursor/skills/`.

Maintainer conventions, including how to add a transformation, are in `docs/conventions.md`;
decisions about this repository are in `docs/decisions/`.

## No warranty

Provided as is. Keep a backup of photographs that matter, whatever tool you use on them.

## License

FSL-1.1-MIT (`LICENSE.md`): source-available, converts to MIT two years after each release.
Copyright 2026 Terry Trippany (Try AI Solutions).
