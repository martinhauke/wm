#!/usr/bin/env bats
#
# Black box tests for wm.sh's own behaviour: argument handling, dispatch,
# recursion, output layout, counters and exit codes.
#
# These run against the magick stub in test/helpers/bin, so they are fast and
# can provoke failure modes the real binary will not produce on demand. The
# flip side is that they say nothing about whether magick still accepts our
# arguments - that is test/e2e.bats' job.

setup() {
  WM="${BATS_TEST_DIRNAME}/../wm.sh"
  PATH="${BATS_TEST_DIRNAME}/helpers/bin:${PATH}"
  export PATH
  D="${BATS_TEST_TMPDIR}/work"
  mkdir -p "$D"
}

# Create a file the stub will happily "read".
make_img() {
  mkdir -p "$(dirname "$1")"
  printf 'INPUT %s' "$1" >"$1"
}

# Fail the test unless $1 exists.
assert_exists() {
  [ -e "$1" ] || {
    echo "expected to exist: $1"
    echo "actually present:"
    find "$D" | sed 's/^/  /'
    return 1
  }
}

assert_missing() {
  [ ! -e "$1" ] || {
    echo "expected NOT to exist: $1"
    return 1
  }
}

# Nothing may ever be left behind under a .wm-tmp- name.
assert_no_temp_files() {
  local leftovers
  leftovers=$(find "${BATS_TEST_TMPDIR}" -name '*wm-tmp*' 2>/dev/null)
  [ -z "$leftovers" ] || {
    echo "leftover temp files: $leftovers"
    return 1
  }
}

############################################################
# Argument handling                                        #
############################################################

@test "no arguments: prints usage and fails" {
  run "$WM"
  [ "$status" -eq 1 ]
  [[ "$output" == Usage:* ]]
}

@test "-h prints the help and succeeds" {
  run "$WM" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Add watermarks to an image"* ]]
  [[ "$output" == *"r     Recurse into subfolders"* ]]
}

@test "an unknown option fails" {
  run "$WM" -Z x
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid option"* ]]
}

@test "a path that is neither a file nor a folder is reported and fails" {
  run "$WM" -t T "$D/nope.jpg"
  [ "$status" -eq 1 ]
  [[ "$output" == *"is not a file or a folder"* ]]
}

@test "an option after the paths gets the ordering hint" {
  make_img "$D/a.jpg"
  run "$WM" -t T "$D/a.jpg" -o "$D/out"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Options have to come before"* ]]
}

@test "-o creates the output folder when it does not exist" {
  make_img "$D/a.jpg"
  run "$WM" -t T -o "$D/brand/new" "$D/a.jpg"
  [ "$status" -eq 0 ]
  assert_exists "$D/brand/new/a_T.jpg"
}

############################################################
# File arguments                                           #
############################################################

@test "a single file writes the result next to the original, without a summary" {
  make_img "$D/a.jpg"
  run "$WM" -t T "$D/a.jpg"
  [ "$status" -eq 0 ]
  assert_exists "$D/a_T.jpg"
  [[ "$output" == *"Saved result to"* ]]
  [[ "$output" != *"Processed"* ]]
}

@test "several file arguments are all processed and summarised" {
  make_img "$D/a.jpg"
  make_img "$D/b.png"
  run "$WM" -t T "$D/a.jpg" "$D/b.png"
  [ "$status" -eq 0 ]
  assert_exists "$D/a_T.jpg"
  assert_exists "$D/b_T.png"
  [[ "$output" == *"Processed 2 file(s), 0 failed."* ]]
}

@test "a file argument with spaces in the name works" {
  make_img "$D/two words.jpg"
  run "$WM" -t T "$D/two words.jpg"
  [ "$status" -eq 0 ]
  assert_exists "$D/two words_T.jpg"
}

@test "the watermark text becomes part of the file name" {
  make_img "$D/a.jpg"
  run "$WM" -t "Some Long Text" "$D/a.jpg"
  [ "$status" -eq 0 ]
  assert_exists "$D/a_Some-Long-Text.jpg"
}

@test "-d puts the date into the file name" {
  make_img "$D/a.jpg"
  run "$WM" -d -t T "$D/a.jpg"
  [ "$status" -eq 0 ]
  assert_exists "$D/a_T-$(date '+%d.%m.%Y').jpg"
}

@test "an explicitly named file is processed even if it looks like our output" {
  make_img "$D/a_T.jpg"
  run "$WM" -t T "$D/a_T.jpg"
  [ "$status" -eq 0 ]
  assert_exists "$D/a_T_T.jpg"
}

############################################################
# Folder arguments                                         #
############################################################

@test "a folder processes its images and skips what magick cannot read" {
  make_img "$D/pics/a.jpg"
  make_img "$D/pics/b.png"
  printf 'text' >"$D/pics/notes.txt"
  printf 'x' >"$D/pics/.DS_Store"
  export WM_STUB_UNREADABLE="notes.txt .DS_Store"

  run "$WM" -t T "$D/pics"
  [ "$status" -eq 0 ]
  assert_exists "$D/pics/a_T.jpg"
  assert_exists "$D/pics/b_T.png"
  assert_missing "$D/pics/notes_T.txt"
  [[ "$output" == *"Processed 2 file(s), 0 failed."* ]]
}

@test "without -r subfolders are left alone" {
  make_img "$D/pics/top.jpg"
  make_img "$D/pics/sub/deep.jpg"
  run "$WM" -t T "$D/pics"
  [ "$status" -eq 0 ]
  assert_exists "$D/pics/top_T.jpg"
  assert_missing "$D/pics/sub/deep_T.jpg"
  [[ "$output" == *"Processed 1 file(s), 0 failed."* ]]
}

@test "-r descends into subfolders" {
  make_img "$D/pics/top.jpg"
  make_img "$D/pics/sub/mid.jpg"
  make_img "$D/pics/sub/deep/low.jpg"
  run "$WM" -t T -r "$D/pics"
  [ "$status" -eq 0 ]
  assert_exists "$D/pics/top_T.jpg"
  assert_exists "$D/pics/sub/mid_T.jpg"
  assert_exists "$D/pics/sub/deep/low_T.jpg"
  [[ "$output" == *"Processed 3 file(s), 0 failed."* ]]
}

@test "-r with -o mirrors the folder structure" {
  make_img "$D/pics/top.jpg"
  make_img "$D/pics/sub/mid.jpg"
  make_img "$D/pics/sub/deep/low.jpg"
  run "$WM" -t T -r -o "$D/out" "$D/pics"
  [ "$status" -eq 0 ]
  assert_exists "$D/out/top_T.jpg"
  assert_exists "$D/out/sub/mid_T.jpg"
  assert_exists "$D/out/sub/deep/low_T.jpg"
  assert_missing "$D/pics/top_T.jpg"
}

@test "-o without -r collects the top level in one flat folder" {
  make_img "$D/pics/a.jpg"
  make_img "$D/pics/b.jpg"
  make_img "$D/pics/sub/deep.jpg"
  run "$WM" -t T -o "$D/out" "$D/pics"
  [ "$status" -eq 0 ]
  assert_exists "$D/out/a_T.jpg"
  assert_exists "$D/out/b_T.jpg"
  assert_missing "$D/out/deep_T.jpg"
}

@test "a symlinked folder is followed" {
  make_img "$D/real/r.jpg"
  ln -s "$D/real" "$D/link"
  run "$WM" -t T "$D/link"
  [ "$status" -eq 0 ]
  assert_exists "$D/real/r_T.jpg"
  [[ "$output" == *"Processed 1 file(s), 0 failed."* ]]
}

@test "-r follows symlinked subfolders" {
  make_img "$D/pics/top.jpg"
  make_img "$D/elsewhere/other.jpg"
  ln -s "$D/elsewhere" "$D/pics/linked"
  run "$WM" -t T -r -o "$D/out" "$D/pics"
  [ "$status" -eq 0 ]
  assert_exists "$D/out/top_T.jpg"
  assert_exists "$D/out/linked/other_T.jpg"
}

@test "a folder and a file can be mixed in one call" {
  make_img "$D/pics/a.jpg"
  make_img "$D/single.jpg"
  run "$WM" -t T "$D/pics" "$D/single.jpg"
  [ "$status" -eq 0 ]
  assert_exists "$D/pics/a_T.jpg"
  assert_exists "$D/single_T.jpg"
  [[ "$output" == *"Processed 2 file(s), 0 failed."* ]]
}

@test "a file with a newline in its name survives the find pipeline" {
  make_img "$D/pics/$(printf 'we\nird').jpg"
  run "$WM" -t T "$D/pics"
  [ "$status" -eq 0 ]
  assert_exists "$D/pics/$(printf 'we\nird')_T.jpg"
}

############################################################
# Running twice over the same folder                       #
############################################################

@test "a folder run is idempotent: results are not watermarked again" {
  make_img "$D/pics/a.jpg"
  make_img "$D/pics/b.jpg"

  run "$WM" -t T "$D/pics"
  [[ "$output" == *"Processed 2 file(s), 0 failed."* ]]

  run "$WM" -t T "$D/pics"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Processed 2 file(s), 0 failed."* ]]
  assert_missing "$D/pics/a_T_T.jpg"
  assert_missing "$D/pics/b_T_T.jpg"
}

@test "a run without -o does not feed its own results back in" {
  for i in 1 2 3 4 5; do make_img "$D/pics/img$i.jpg"; done
  run "$WM" -t T "$D/pics"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Processed 5 file(s), 0 failed."* ]]
}

@test "a glob is a list of explicit files, so a second run does stack watermarks" {
  # The shell expands the glob before wm.sh starts, so wm.sh cannot tell this
  # apart from a hand typed list - and explicitly named files are always
  # processed. Documented in the README; pinned here so it stays a decision.
  make_img "$D/pics/a.jpeg"
  make_img "$D/pics/b.jpeg"

  run "$WM" -t T "$D"/pics/*.jpeg
  [ "$status" -eq 0 ]
  [[ "$output" == *"Processed 2 file(s), 0 failed."* ]]

  run "$WM" -t T "$D"/pics/*.jpeg
  [ "$status" -eq 0 ]
  [[ "$output" == *"Processed 4 file(s), 0 failed."* ]]
  assert_exists "$D/pics/a_T_T.jpeg"
}

@test "the folder form stays idempotent where the glob form does not" {
  make_img "$D/pics/a.jpeg"
  make_img "$D/pics/b.jpeg"

  run "$WM" -t T "$D/pics"
  run "$WM" -t T "$D/pics"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Processed 2 file(s), 0 failed."* ]]
  assert_missing "$D/pics/a_T_T.jpeg"
}

@test "a quoted glob is not expanded and is reported as missing" {
  make_img "$D/pics/a.jpeg"
  run "$WM" -t T "$D/pics/*.jpeg"
  [ "$status" -eq 1 ]
  [[ "$output" == *"is not a file or a folder"* ]]
  assert_missing "$D/pics/a_T.jpeg"
}

@test "a different watermark text is not treated as our own output" {
  make_img "$D/pics/a.jpg"
  run "$WM" -t T "$D/pics"
  run "$WM" -t OTHER "$D/pics"
  [ "$status" -eq 0 ]
  assert_exists "$D/pics/a_OTHER.jpg"
  assert_exists "$D/pics/a_T_OTHER.jpg"
}

############################################################
# Failures                                                 #
############################################################

@test "a failing magick is reported, counted and exits 1" {
  make_img "$D/a.jpg"
  export WM_STUB_MODE=fail
  run "$WM" -t T "$D/a.jpg"
  [ "$status" -eq 1 ]
  [[ "$output" == *"magick failed with exit code 1"* ]]
  assert_missing "$D/a_T.jpg"
  assert_no_temp_files
}

@test "a partial write leaves no truncated file behind" {
  make_img "$D/a.jpg"
  export WM_STUB_MODE=partial
  run "$WM" -t T "$D/a.jpg"
  [ "$status" -eq 1 ]
  assert_missing "$D/a_T.jpg"
  assert_no_temp_files
}

@test "a failed run never destroys the result of an earlier successful one" {
  make_img "$D/a.jpg"
  run "$WM" -t T "$D/a.jpg"
  [ "$status" -eq 0 ]
  before=$(cat "$D/a_T.jpg")

  export WM_STUB_MODE=partial
  run "$WM" -t T "$D/a.jpg"
  [ "$status" -eq 1 ]
  [ "$(cat "$D/a_T.jpg")" = "$before" ]
  assert_no_temp_files
}

@test "one broken file does not stop the rest of the folder" {
  make_img "$D/pics/good1.jpg"
  make_img "$D/pics/bad.jpg"
  make_img "$D/pics/good2.jpg"
  export WM_STUB_MODE=fail_on_bad

  # The stub only knows ok/fail/partial, so drive the failure through a
  # wrapper that fails for the one file.
  cat >"${BATS_TEST_TMPDIR}/magick" <<'STUB'
#!/bin/bash
if [ "$1" = "identify" ]; then exit 0; fi
case "$1" in *bad.jpg) exit 1;; esac
for out in "$@"; do :; done
printf 'FAKE' >"$out"
STUB
  chmod +x "${BATS_TEST_TMPDIR}/magick"
  PATH="${BATS_TEST_TMPDIR}:${PATH}"

  run "$WM" -t T "$D/pics"
  [ "$status" -eq 1 ]
  assert_exists "$D/pics/good1_T.jpg"
  assert_exists "$D/pics/good2_T.jpg"
  assert_missing "$D/pics/bad_T.jpg"
  [[ "$output" == *"Processed 2 file(s), 1 failed."* ]]
}

@test "an unreadable subfolder warns but does not count as a failure" {
  make_img "$D/pics/ok.jpg"
  mkdir -p "$D/pics/locked"
  make_img "$D/pics/locked/hidden.jpg"
  chmod 000 "$D/pics/locked"

  run "$WM" -t T -r -o "$D/out" "$D/pics"
  chmod 755 "$D/pics/locked"

  [ "$status" -eq 0 ]
  [[ "$output" == *"find exited with code"* ]]
  [[ "$output" == *"0 failed."* ]]
  assert_exists "$D/out/ok_T.jpg"
}

############################################################
# What we actually ask magick for                          #
#                                                          #
# This pins the argument list. It cannot tell us whether   #
# magick still ACCEPTS it - see test/e2e.bats.             #
############################################################

@test "the watermarking call passes the size, the text and -strip" {
  make_img "$D/a.jpg"
  export WM_STUB_ARGS_FILE="${BATS_TEST_TMPDIR}/args"
  run "$WM" -s 800 -t "Hello" "$D/a.jpg"
  [ "$status" -eq 0 ]

  # The last recorded call is the watermarking one.
  local call
  call=$(grep -v '^identify ' "$WM_STUB_ARGS_FILE" | tail -1)
  [[ "$call" == *"-size 800x"* ]]
  [[ "$call" == *"label:Hello"* ]]
  [[ "$call" == *"-strip"* ]]
  [[ "$call" == *"mpr:wm"* ]]
}

@test "magick writes to a temp path that keeps the extension" {
  make_img "$D/a.JPG"
  export WM_STUB_ARGS_FILE="${BATS_TEST_TMPDIR}/args"
  run "$WM" -t T "$D/a.JPG"
  [ "$status" -eq 0 ]

  local call
  call=$(grep -v '^identify ' "$WM_STUB_ARGS_FILE" | tail -1)
  [[ "$call" == *".wm-tmp-"*".JPG" ]]
  assert_exists "$D/a_T.JPG"
}
