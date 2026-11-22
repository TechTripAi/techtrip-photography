# ADR-001: Image transformations: one skill with recipes, non-destructive, verified, macOS first

**Status:** Accepted
**Date:** 2026-11-22
**Deciders:** Terry

## Context
The first need was concrete. Photographs exported from Apple Photos as unmodified originals
are HEIC files. Edits made on them in two editors looked right and then looked different
when the files were reopened, which does not happen with RAW or TIFF files. The files hold
an HDR gain map and other auxiliary images beside the main image, and that is the likely
cause, though it was not proven. Converting to TIFF gives each photograph a single
rendition.

Three things were found while doing it by hand:

- `sips`, the macOS tool that decodes HEIC as Apple's own software does, accepts an LZW
  option for TIFF and ignores it. Its output is uncompressed.
- `sips` writes the image as one tile the size of the whole picture. After recompression,
  one such file could not be read back by macOS. Strips were read every time.
- Recompressing with `tiffcp` drops EXIF, GPS and XMP, and copying them back with
  `exiftool` in its default mode rounds values such as the f-number.

The folder that prompted the work also showed the risk on the other side: the exported
originals had been written into by editors within hours and were no longer originals.

More transformations will follow, and the plugin is to work in more than one AI tool.

## Options considered
1. One skill per transformation (`heic-to-tiff`, then another for each new one). Each is
   simple, but every one repeats the safety rules, the selection flow and the reporting,
   and the list of skills a user sees grows with every format.
2. One skill, `image-transform-tools`, with a recipe per transformation: a script and a
   reference file each, sharing one library for file order, selection, the run log, reports
   and the safety rules (this decision).
3. Use the Apple Photos TIFF export and no plugin. It bakes in edits made in Photos, gives
   no control over compression and cannot be checked against the originals.
4. Decode with libheif or ImageMagick so that it runs on every operating system. A
   different decoder may render colour differently from Apple's, so the output could not
   be said to match what the user sees in Apple's software.

## Decision
Option 2, with the decoder from macOS.

- **Non-destructive by construction.** A source is never changed, moved or deleted. An
  existing file is never replaced; the source is skipped and reported. Two sources that
  would produce the same output name are both skipped. Only temp files the run created are
  removed, by exact path. The scripts hold these rules, so they hold in every AI tool and
  when a script is run by hand.
- **Verified by default.** Each output is decoded and compared with its source pixel for
  pixel before it is given its name, and its capture metadata is compared. A pixel
  difference fails the file and nothing is kept. A metadata difference is kept with a note.
- **Built under a temp name in the destination, then renamed.** An interrupted run leaves
  no half-written file with a real name, and the rename does not cross volumes.
- **Selection by ticking checkboxes.** The requirement was a list to tick, not numbers to
  type. An AI tool's own picker is not available in every tool and the one in Claude Code
  holds four options. The window is therefore opened by the operating system through
  `osascript`, which every tool's shell can call. Numbers from a printed list remain as the
  fallback where no window can be opened.
- **Preflight advises.** It names what is missing and the command that installs it.
- **macOS for the HEIC recipe.** On other systems preflight says so and nothing runs.
- **Source bit depth is kept.** No 16-bit option: it would double the size of 8-bit
  sources and add nothing.

## Consequences
- A second recipe is a script, a reference file and a table row. The shared library must
  stay recipe-neutral.
- The plugin installs on Linux and Windows and reports that conversion is not supported
  there. A decoder path for those systems would be a separate recipe with its own statement
  of what it can and cannot guarantee.
- Redoing an output means the user moves the old file first. That is deliberate.
- Pixel verification is at 8 bits per channel. It is exact for 8-bit sources and coarser
  for deeper ones; the recipe's reference file says so.
- Progress is text first. A bar that redraws itself is unreadable in captured output, so
  each line carries a counter and the time left, a status file can be polled, and the bar
  is drawn only on a terminal. A progress window was first left out and then added
  after the first real batch: the agent reported "3 of 61" once and went quiet until the
  end, because it can speak only when it takes a turn. The window reads the same status
  file, takes no input and closes itself.
- The questions are asked on every run. On a second run in one conversation the agent
  reused the earlier folder choice without saying so; proposals may repeat last time's
  answers, but the user confirms them.
- Subfolders are read only on request, and the destination then mirrors them. That keeps
  two files of the same name in different subfolders apart without renaming anything.
- The skill asks every question before a window opens. A window from a chat tool is
  unusual; it is kept to one, opened once, after the user has been told.
