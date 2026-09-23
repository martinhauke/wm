#!/usr/bin/env bats
#
# Unit tests for the pure helper functions. wm.sh is sourced with
# WM_LIB_ONLY=true, so nothing is executed and no magick is involved.
#
# is_magick_readable is not tested here - it is a one line call into magick and
# belongs in test/e2e.bats, where the real binary answers.

setup() {
  export WM_LIB_ONLY=true
  # shellcheck source=../wm.sh disable=SC1091
  source "${BATS_TEST_DIRNAME}/../wm.sh"
  file_name_postfix="T"
}

############################################################
# build_output_path                                        #
############################################################

@test "build_output_path: inserts the postfix before the extension" {
  run build_output_path "/a/b/c.jpg" "/out"
  [ "$output" = "/out/c_T.jpg" ]
}

@test "build_output_path: preserves the case of the extension" {
  run build_output_path "/a/b/c.JPG" "/out"
  [ "$output" = "/out/c_T.JPG" ]
}

@test "build_output_path: only the last dot counts as the extension" {
  run build_output_path "/a/my.holiday.pic.jpeg" "/out"
  [ "$output" = "/out/my.holiday.pic_T.jpeg" ]
}

@test "build_output_path: keeps spaces in the name" {
  run build_output_path "/a/b c.png" "/out dir"
  [ "$output" = "/out dir/b c_T.png" ]
}

@test "build_output_path: an empty target folder means the current directory" {
  run build_output_path "c.jpg" ""
  [ "$output" = "./c_T.jpg" ]
}

@test "build_output_path: uses the dated postfix when -d was given" {
  file_name_postfix="T-19.03.2024"
  run build_output_path "/a/c.jpg" "/out"
  [ "$output" = "/out/c_T-19.03.2024.jpg" ]
}

############################################################
# is_own_output - guards against watermarking our own      #
# results when a folder is processed twice                 #
############################################################

@test "is_own_output: recognises the result of an earlier run" {
  run is_own_output "/a/img_T.jpg"
  [ "$status" -eq 0 ]
}

@test "is_own_output: leaves an untouched original alone" {
  run is_own_output "/a/img.jpg"
  [ "$status" -eq 1 ]
}

@test "is_own_output: a different watermark is not our own output" {
  run is_own_output "/a/img_SOMETHINGELSE.jpg"
  [ "$status" -eq 1 ]
}

@test "is_own_output: the postfix has to be at the end" {
  run is_own_output "/a/img_T_more.jpg"
  [ "$status" -eq 1 ]
}

@test "is_own_output: works with a dated postfix" {
  file_name_postfix="T-19.03.2024"
  run is_own_output "/a/img_T-19.03.2024.jpg"
  [ "$status" -eq 0 ]
  run is_own_output "/a/img_T.jpg"
  [ "$status" -eq 1 ]
}

@test "is_own_output: a name without an extension does not crash it" {
  run is_own_output "/a/README"
  [ "$status" -eq 1 ]
}
