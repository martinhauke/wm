# wm

Add watermark to a picture, or to every picture in a folder. I wrote this mainly to put annoying but visible marks on copies of my ID card before sending it somewhere.
It's neither pretty nor clever but get's the work done. It will also strip the metadata of the resulting image.

It will not overwrite the original image. Instead, it will create a new image next to it (the watermark text will be appended to the file name).

## Prerequisites

* `magick` (part of the [imagemagick](https://imagemagick.org/script/download.php) v7 tools)

## Usage

```shell
wm [-dhr] [-s size] [-t text] [-o outdir] file|folder ...

Options:
d     Add the current date to the watermark.
h     Print this Help.
o     Output folder. Defaults to the folder of each input image.
r     Recurse into subfolders of a folder argument.
s     Set the font size.
t     Set the text.
```

Every argument can be a file or a folder, and you can pass as many as you like:

```shell
./wm.sh -t "foo" ~/pictures/a.jpg ~/pictures/b.png     # two files
./wm.sh -t "foo" ~/pictures/*.jpg                      # whatever the shell expands to
./wm.sh -t "foo" -r ~/pictures                         # a whole folder tree
```

By default wm will save the output to a separate file next to the original. Use `-o` to
collect the results in a different folder instead.

Note that options have to come *before* the file and folder arguments.

### `-h` Help

Print the help text.

### `-d` Date

Adds the current date (dd.MM.YYYY) below each occurrence of the watermark text

### `-s size` Size

The text size. It's not an exact size and depends a lot on how big the image and how long the text is. `800` is usually a good starting point.

### `-t text`

Set the watermark text.

### Folder arguments

If an argument is a folder, every image in it is watermarked. There is no hardcoded
list of extensions - `magick` is asked whether it can read the file, so whatever your
ImageMagick supports works. Files it cannot read (`notes.txt`, `.DS_Store`, ...) are
skipped silently rather than counted as errors.

The flip side is that "is this an image" is magick's call, not a judgement about what
you probably meant: a PDF or an SVG sitting in the folder gets watermarked too. Name
such a file explicitly if you want it, or point wm at a folder that only has pictures
in it.

If a single image fails, the error is printed and the remaining files are still
processed. The script prints a summary at the end and exits with `1` if at least one
file failed.

### Running wm twice, and why globs behave differently

Pointing wm at a **folder** twice does not stack watermarks. Results of an earlier run
with the same text and date are recognised and skipped:

```shell
./wm.sh -t T ~/pictures        # Processed 3 file(s), 0 failed.
./wm.sh -t T ~/pictures        # Processed 3 file(s), 0 failed.  <- the same 3
```

A **glob** is a different thing, even though it looks similar. The shell expands
`~/pictures/*.jpeg` before wm ever starts, so wm receives a plain list of file paths
and cannot tell it apart from a hand typed one. Explicitly named files are always
processed - that is the point of naming them - so an earlier `a_T.jpeg` matches the
glob the second time around and gets watermarked again:

```shell
./wm.sh -t T ~/pictures/*.jpeg  # Processed 3 file(s), 0 failed.
./wm.sh -t T ~/pictures/*.jpeg  # Processed 6 file(s), 0 failed.  <- a_T_T.jpeg
```

Use the folder form if you want to be able to re-run it safely.

Quoting the glob does not help either - then the shell hands wm the literal string and
there is no such file:

```shell
./wm.sh -t T "~/pictures/*.jpeg"
Error: '~/pictures/*.jpeg' is not a file or a folder.
```

### `-o folder` Output folder

Write the results into this folder instead of next to the originals. The folder is
created if it does not exist. The watermark suffix is appended to the file name either
way.

### `-r` Recursive

Also process images in subfolders of a folder argument. Together with `-o` the folder
structure is recreated below the output folder. It has no effect on file arguments.

### example for single file

```shell
./wm.sh -d -s 900 -t "Copy for some important place" ~/pictures/id/id_censored.jpeg

Saved result to /users/username/pictures/id/id_censored_Copy-for-some-important-place-19.03.2024.jpeg
```

### batch example

```shell
./wm.sh -d -s 800 -t "watermark text" -r ~/pictures/website -o ~/pictures/watermarked

Saved result to /users/username/pictures/watermarked/image_watermark-text-20.09.2026.jpg
...
Processed 24 file(s), 0 failed.
```

## Tests

The suite uses [bats](https://github.com/bats-core/bats-core) (`brew install bats-core`).

```shell
bats test/                 # everything
bats test/unit.bats        # the pure helpers, no magick involved
bats test/cli.bats         # wm.sh's behaviour, against a magick stub
bats test/e2e.bats         # against the real magick
```

It is in three layers on purpose:

* **`test/unit.bats`** sources `wm.sh` with `WM_LIB_ONLY=true`, which defines the
  functions without running anything, and tests the pure string handling.
* **`test/cli.bats`** drives the script through its CLI with a fake `magick` on `PATH`
  (`test/helpers/bin/magick`). That keeps it fast and lets it provoke failures the real
  binary will not produce on demand - a crash *after* a partial write, for instance.
* **`test/e2e.bats`** runs the real ImageMagick. A stub can only ever confirm that we
  send the arguments we think we send, never that magick still accepts them - and this
  repo has already been broken by exactly that (`2851f17`, "use magick instead of
  convert"). So every distinct way `wm.sh` calls magick is exercised here for real.

`test/e2e.bats` skips itself when `magick` is missing, which would quietly hide the
breakage it exists to catch. Set `WM_REQUIRE_MAGICK=1` to turn that skip into a hard
failure; CI does:

```shell
WM_REQUIRE_MAGICK=1 bats test/
```
