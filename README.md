# wm

Add watermark to a picture. I wrote this mainly to put anoying but visible marks on copies of my ID card before sending somewhere.
It's neither pretty nor clever but get's the work done.

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
wm -d -s 900 -t "Copy for some important place" ~/pictures/id/id_censored.jpeg
```
