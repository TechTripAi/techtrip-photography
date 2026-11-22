# Recipe: HEIC or HEIF to TIFF, no further loss

Script: `scripts/heic-to-tiff.sh`. Runs on macOS.

## What it produces

For each `.heic` or `.heif` file in the source folder, one `.tif` file of the same name in
the destination folder:

- the pixels are exactly what macOS decodes from the source, at the source's own bit depth
- the colour profile is the source's (Display P3 for most iPhone photos); no colour
  conversion is done
- capture date, location, camera, lens and exposure data are copied across, unrounded
- compression is LZW with a predictor, which is lossless; `--compression none` writes it
  uncompressed, also lossless and about three to four times larger
- the image is stored in strips, the layout the widest range of software reads

## What "no loss" means, and does not

A HEIC is already compressed with loss when the camera writes it. This recipe adds no
further loss: every later save of the TIFF keeps what the HEIC held. It cannot bring back
what the camera's compression discarded.

A TIFF is much larger than its HEIC, typically eight to ten times with LZW. That is the cost
of storing every pixel exactly.

Most phone HEICs are 8 bits per channel. Writing them as 16-bit would double the size and
add no detail, so the recipe keeps the source's depth and has no 16-bit option.

## What is not carried into the TIFF

A phone HEIC is a container. Besides the main image it can hold:

- an **HDR gain map**: the extra brightness shown on HDR displays
- depth data and mattes used for portrait effects
- for a Live Photo, a separate video file beside it

A TIFF holds one image, so it gets the standard image and none of these. That is the point
of converting for many people, see the next section. Someone who needs the HDR rendition
should keep working from the HEIC, which stays where it was.

## Why an editor's view of a HEIC can change

A common report: edits on a HEIC look right, and the picture looks different when the file
is reopened or passed to another program, while RAW and TIFF files never do this.

The likely cause is the gain map. Programs differ in whether they apply it, and one program
may show the image with it in one place and without it in another. This is a likely
explanation, not a proven one for any particular case. A TIFF has a single rendition, so
there is nothing for programs to disagree about. The test is practical: edit the TIFF, close
it, reopen it, and see that it holds.

## Steps, and why each is there

1. **Decode with `sips`**, the decoder macOS itself uses, into an uncompressed TIFF. The
   same decoder Apple Photos and Preview use, so the result matches what the user sees there.
2. **Recompress with `tiffcp`** as LZW in strips. `sips` accepts an LZW option and ignores
   it, and it writes the whole image as one tile, which some readers refuse.
3. **Copy the metadata back with `exiftool`**, because step 2 drops EXIF, GPS and XMP.
   Values are copied as numbers so nothing is rounded.
4. **Verify** (next section).
5. **Give the file its name**, only if nothing has that name.

The TIFF is built under a temporary name in the destination folder and renamed at the end,
so a run that is interrupted leaves no half-written file with a real name.

## Verification

On by default. For each file, before it is given its name:

- **Pixels:** the source and the new TIFF are each decoded and compared byte for byte. A
  difference fails the file and nothing is kept.
- **Format:** the TIFF has the compression that was asked for.
- **Metadata:** capture date and offset, latitude, longitude, make, model, lens, exposure
  time, f-number, ISO and focal length are compared. A difference does not fail the file;
  it is kept and carries a note naming the fields.

The pixel comparison is made at 8 bits per channel. For a source with more than 8 bits it
is still a real check, but a coarser one; say so if the listing shows more than 8 bits.

`--no-verify` skips all three and reports files as "converted" rather than "verified". It
roughly halves the time per file.

## How long it takes

About one and a half to two seconds for a 24-megapixel photo with verification, on a recent
Mac with the files on a fast drive. Sixty photos take around two minutes; five hundred,
around a quarter of an hour. Each line a run prints says about how long is left.

## Options

| Option | Meaning |
|---|---|
| `--select <list>` | `all` (default), or numbers and ranges from `list.sh`: `1-5,9` |
| `--recursive` | Also read subfolders; each output goes in the same subfolder of the destination |
| `--dry-run` | Say what would happen; write nothing, not even the destination folder |
| `--no-verify` | Skip verification |
| `--compression lzw\|none` | Default `lzw` |
| `--progress-file auto\|<path>` | Keep a status file up to date for `status.sh` (`report-format.md`) |
| `--progress-window` | Show a small window with a progress bar; it closes itself when the run ends |
| `--report md\|csv` | Also write a report file (`report-format.md`) |
| `--report-dir <dir>` | Where the report goes; default is the destination folder |

## Which files are read

Files in the source folder whose names end in `.heic` or `.heif`, in any letter case,
sorted by name. Subfolders are entered only with `--recursive`; then the destination gets
the same subfolders, so two files of the same name in different subfolders do not clash.
`list.sh`, `pick.sh` and the recipe must all be given `--recursive`, or none of them,
because it changes the numbering.

Files and folders whose names start with a dot are ignored, which leaves out the `._name`
companions macOS writes on non-Apple drives.

## Getting originals out of Apple Photos

To convert what the camera wrote, export it unchanged: in Photos, select the photos, then
File, Export, Export Unmodified Original. The files come out as HEIC because that is what
the phone recorded; that export has no format choice.

Photos can also export TIFF itself (File, Export, Export Photos, with Photo Kind set to
TIFF). That bakes in any edits made in Photos, gives no control over compression, and cannot
be checked against the originals, which is why this recipe starts from unmodified originals.

Keep the exported HEICs in a folder editors are not pointed at. Some editors write their
settings into the HEIC file itself, and after that it is no longer the original.
