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

If an argument is a folder, every image in it is watermarked. Only files with a known
image extension are considered (`jpg`, `jpeg`, `png`, `tif`, `tiff`, `webp`, `heic`,
`gif`, `bmp`); anything else is skipped silently.

If a single image fails, the error is printed and the remaining files are still
processed. The script prints a summary at the end and exits with `1` if at least one
file failed.

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
