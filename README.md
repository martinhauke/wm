# wm

Add watermark to a picture, or to every picture in a folder. I wrote this mainly to put annoying but visible marks on copies of my ID card before sending it somewhere.
It's neither pretty nor clever but get's the work done. It will also strip the metadata of the resulting image.

It will not overwrite the original image. Instead, it will create a new image next to it (the watermark text will be appended to the file name).

## Prerequisites

* `magick` (part of the [imagemagick](https://imagemagick.org/script/download.php) v7 tools)

## Usage

```shell
wm [-dhr] [-s size] [-t text] [-o outdir] (-i indir | file)

Options:
d     Add the current date to the watermark.
h     Print this Help.
i     Input folder. Watermark every image in it instead of a single file.
o     Output folder. Defaults to the folder of each input image.
r     Recurse into subfolders (only with -i). Mirrors the tree in the output folder.
s     Set the font size.
t     Set the text.
```

By default wm will save the output to a separate file next to the original. Use `-o` to
collect the results in a different folder instead.

Note that options have to come *before* the file argument.

### `-h` Help

Print the help text.

### `-d` Date

Adds the current date (dd.MM.YYYY) below each occurrence of the watermark text

### `-s size` Size

The text size. It's not an exact size and depends a lot on how big the image and how long the text is. `800` is usually a good starting point.

### `-t text`

Set the watermark text.

### `-i folder` Input folder

Watermark every image in the folder instead of a single file. Only files with a known
image extension are considered (`jpg`, `jpeg`, `png`, `tif`, `tiff`, `webp`, `heic`,
`gif`, `bmp`); anything else is skipped silently.

If a single image fails, the error is printed and the remaining files are still
processed. The script prints a summary at the end and exits with `1` if at least one
file failed.

`-i` and a file argument are mutually exclusive.

### `-o folder` Output folder

Write the results into this folder instead of next to the originals. The folder is
created if it does not exist. The watermark suffix is appended to the file name either
way.

### `-r` Recursive

Only useful together with `-i`. Also processes images in subfolders and recreates the
folder structure below the output folder.

### example for single file

```shell
sh ./wm.sh -d -s 900 -t "Copy for some important place" ~/pictures/id/id_censored.jpeg

Saved result to /users/username/pictures/id/id_censored-copy-for-some-important-place-19.03.2024.jpg
```

### batch example

```shell
sh ./wm.sh -d -s 800 -t "watermark text" -r -i ~/pictures/website -o ~/pictures/watermarked

Saved result to /users/username/pictures/watermarked/image-20.09.2026.jpg
...
Processed 24 file(s), 0 failed.
```
