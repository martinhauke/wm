#!/usr/bin/env bats
#
# End to end tests against the REAL imagemagick.
#
# This is the layer that catches ImageMagick changing under us - the thing the
# stub in test/cli.bats is blind to by construction. It already happened once
# in this repo: commit 2851f17 "use magick instead of convert and specify
# font". Every distinct way wm.sh invokes magick has to be exercised here.
#
# If magick is missing these tests skip - which would quietly hide exactly the
# breakage they exist to find. So CI sets WM_REQUIRE_MAGICK=1, and then a
# missing magick is a hard failure instead of a skip.

setup() {
  WM="${BATS_TEST_DIRNAME}/../wm.sh"

  if ! command -v magick >/dev/null 2>&1; then
    if [ -n "${WM_REQUIRE_MAGICK:-}" ]; then
      echo "magick is not installed, but WM_REQUIRE_MAGICK is set." >&2
      echo "Refusing to skip the tests that verify the magick contract." >&2
      return 1
    fi
    skip "imagemagick (magick) is not installed"
  fi

  D="${BATS_TEST_TMPDIR}/work"
  mkdir -p "$D"
}

# A real image of the given solid colour.
make_real_img() {
  local path="$1" colour="${2:-white}"
  mkdir -p "$(dirname "$path")"
  magick -size 200x120 "xc:${colour}" "$path"
}

# Fail unless $1 is an image magick can read.
assert_valid_image() {
  magick identify -ping "$1" >/dev/null 2>&1 || {
    echo "not a readable image: $1"
    return 1
  }
}

mean_of() {
  magick "$1" -format '%[fx:mean]' info:
}

############################################################
# The core contract: our argument list still works         #
############################################################

@test "a real jpeg comes out as a valid jpeg of the same size" {
  make_real_img "$D/a.jpg"
  run "$WM" -s 200 -t "Test" "$D/a.jpg"
  [ "$status" -eq 0 ]
  [ -e "$D/a_Test.jpg" ]
  assert_valid_image "$D/a_Test.jpg"
  [ "$(magick identify -format '%m %wx%h' "$D/a_Test.jpg")" = "JPEG 200x120" ]
}

@test "the watermark is actually drawn onto the image" {
  make_real_img "$D/a.jpg" white
  before=$(mean_of "$D/a.jpg")
  run "$WM" -s 200 -t "Test" "$D/a.jpg"
  [ "$status" -eq 0 ]
  after=$(mean_of "$D/a_Test.jpg")

  # The watermark is drawn semi transparent dark over white, so the mean
  # brightness has to drop. If magick silently stopped compositing, this is
  # the assertion that notices.
  run awk -v a="$before" -v b="$after" 'BEGIN { exit !(b < a) }'
  [ "$status" -eq 0 ] || {
    echo "mean did not drop: before=$before after=$after"
    return 1
  }
}

@test "-strip removes the metadata" {
  mkdir -p "$D"
  magick -size 200x120 xc:white -set 'exif:Make' 'TESTCAM' "$D/a.jpg"
  run "$WM" -s 200 -t "Test" "$D/a.jpg"
  [ "$status" -eq 0 ]
  [ -z "$(magick identify -format '%[EXIF:Make]' "$D/a_Test.jpg" 2>/dev/null)" ]
}

@test "-d renders the two line label without magick complaining" {
  make_real_img "$D/a.jpg"
  run "$WM" -d -s 200 -t "Test" "$D/a.jpg"
  [ "$status" -eq 0 ]
  [[ "$output" != *"magick failed"* ]]
  assert_valid_image "$D/a_Test-$(date '+%d.%m.%Y').jpg"
}

@test "png, tiff and webp round trip too" {
  for ext in png tif webp; do
    make_real_img "$D/pic.${ext}"
    run "$WM" -s 200 -t "Test" "$D/pic.${ext}"
    [ "$status" -eq 0 ] || {
      echo "failed for .${ext}: $output"
      return 1
    }
    assert_valid_image "$D/pic_Test.${ext}"
  done
}

@test "an uppercase extension is preserved and still produces a valid image" {
  make_real_img "$D/a.JPG"
  run "$WM" -s 200 -t "Test" "$D/a.JPG"
  [ "$status" -eq 0 ]
  assert_valid_image "$D/a_Test.JPG"
}

############################################################
# is_magick_readable, answered by the real binary           #
############################################################

@test "is_magick_readable accepts a real image and rejects a text file" {
  export WM_LIB_ONLY=true
  # shellcheck source=../wm.sh disable=SC1091
  source "$WM"

  make_real_img "$D/a.jpg"
  run is_magick_readable "$D/a.jpg"
  [ "$status" -eq 0 ]

  printf 'just some text\n' >"$D/notes.txt"
  run is_magick_readable "$D/notes.txt"
  [ "$status" -ne 0 ]

  printf 'x' >"$D/.DS_Store"
  run is_magick_readable "$D/.DS_Store"
  [ "$status" -ne 0 ]
}

@test "letting magick decide means whatever it supports is picked up" {
  # No extension allowlist, so a format the installed magick knows about is
  # processed without wm.sh having to know its name. avif is skipped when the
  # local build has no delegate for it.
  if ! magick -size 10x10 xc:white "$D/probe.avif" >/dev/null 2>&1; then
    skip "this imagemagick build cannot write avif"
  fi
  make_real_img "$D/pics/a.jpg"
  magick -size 200x120 xc:white "$D/pics/modern.avif"

  run "$WM" -s 200 -t "Test" "$D/pics"
  [ "$status" -eq 0 ]
  assert_valid_image "$D/pics/a_Test.jpg"
  assert_valid_image "$D/pics/modern_Test.avif"
}

@test "documents magick reads are watermarked too - this is a known trade off" {
  mkdir -p "$D/pics"
  printf '%s\n' '<svg xmlns="http://www.w3.org/2000/svg" width="40" height="40"><rect width="40" height="40"/></svg>' >"$D/pics/pic.svg"
  run "$WM" -s 200 -t "Test" "$D/pics"
  [ "$status" -eq 0 ]
  # Deliberate: "is it an image" is magick's call, and magick says yes to SVG.
  [ -e "$D/pics/pic_Test.svg" ]
}

############################################################
# Real failure path                                        #
############################################################

@test "a corrupt image fails cleanly and leaves nothing behind" {
  mkdir -p "$D"
  printf 'this is definitely not a jpeg' >"$D/broken.jpg"
  run "$WM" -s 200 -t "Test" "$D/broken.jpg"
  [ "$status" -eq 1 ]
  [[ "$output" == *"magick failed"* ]]
  [ ! -e "$D/broken_Test.jpg" ]
  [ -z "$(find "$BATS_TEST_TMPDIR" -name '*wm-tmp*')" ]
}

@test "a corrupt image never destroys the result of an earlier run" {
  make_real_img "$D/a.jpg"
  run "$WM" -s 200 -t "Test" "$D/a.jpg"
  [ "$status" -eq 0 ]
  before=$(shasum <"$D/a_Test.jpg")

  printf 'no longer a jpeg' >"$D/a.jpg"
  run "$WM" -s 200 -t "Test" "$D/a.jpg"
  [ "$status" -eq 1 ]
  [ "$(shasum <"$D/a_Test.jpg")" = "$before" ]
  [ -z "$(find "$BATS_TEST_TMPDIR" -name '*wm-tmp*')" ]
}

############################################################
# A real folder run                                        #
############################################################

@test "a recursive real run produces valid images throughout the mirrored tree" {
  make_real_img "$D/in/top.jpg" white
  make_real_img "$D/in/sub/mid.png" white
  make_real_img "$D/in/sub/deep/low.jpg" white
  printf 'text' >"$D/in/notes.txt"

  run "$WM" -s 200 -t "Test" -r -o "$D/out" "$D/in"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Processed 3 file(s), 0 failed."* ]]

  assert_valid_image "$D/out/top_Test.jpg"
  assert_valid_image "$D/out/sub/mid_Test.png"
  assert_valid_image "$D/out/sub/deep/low_Test.jpg"
  [ ! -e "$D/out/notes_Test.txt" ]
}
