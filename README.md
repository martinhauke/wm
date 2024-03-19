# wm

Add watermark to a picture. I wrote this mainly to put anoying but visible marks on copies of my ID card before sending it somewhere.
It's neither pretty nor clever but get's the work done. It will also strip the metadata of the resulting image.

It will not overwrite the original image. Instead, it will create a new image next to it (the watermark text will be appended to the file name).

## Prerequisites

* convert (part of the [imagemagick](https://imagemagick.org/script/download.php) tools)

## Usage

```shell
wm [-dh] [-s size] [-t text] file

Options:
d     Add the current date to the watermark.
h     Print this Help.
s     Set the font size.
t     Set the text.
```

wm will save the output to a separate file next to the original.

### `-h` Help

Print the help text.

### `-d` Date

Adds the current date (dd.MM.YYYY) below each occurance of the watermark text

### `-s size` Size

The text size. It's not an exact size and depends a lot on how big the image and how long the text is. `800` is usually a good starting point.

### `-t text`

Set the watermark text.

### example

```shell
sh ./wm.sh -d -s 900 -t "Copy for some important place" ~/pictures/id/id_censored.jpeg

Saved result to /users/username/pictures/id/id_censored-copy-for-some-important-place-19.03.2024.jpg
```
