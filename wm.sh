#!/bin/bash
############################################################
# Help                                                     #
############################################################

usage_string="Usage: $(basename "$0") [-dhr] [-s size] [-t text] [-o outdir] file|folder ..."

Help()
{
   # Display Help
   echo "Add watermarks to an image or to every image in a folder."
   echo
   echo "$usage_string"
   echo
   echo "Options:"
   echo "d     Add the current date to the watermark."
   echo "h     Print this Help."
   echo "o     Output folder. Defaults to the folder of each input image."
   echo "r     Recurse into subfolders of a folder argument."
   echo "s     Set the font size."
   echo "t     Set the text."
   echo
}

############################################################
# Helpers                                                  #
############################################################

# Build the output path for $1 (source file) inside $2 (target directory).
build_output_path()
{
  local _dest_dir="$2" _basename _without_extension _extension
  [ -n "$_dest_dir" ] || _dest_dir="."
  _basename=$(basename "$1")
  _without_extension="${_basename%.*}"
  _extension="${_basename##*.}"
  printf '%s\n' "${_dest_dir}/${_without_extension}_${file_name_postfix}.${_extension}"
}

# Add the watermark to $1 and write the result to $2.
watermark_file()
{
  magick "$1" \
  \( -size "${font_size}x" -background none -fill "#8339" -gravity center -font "${font}" \
  label:"${wm_text}" -trim -rotate -10 \
  -bordercolor none -border 5 \
  -write mpr:wm +delete \
  +clone -fill mpr:wm  -draw 'color 0,0 reset' \) \
  -compose over -composite \
  -strip \
  "$2"
}

# Return 0 if $1 already looks like the result of an earlier run with the same
# text and date, so that repeatedly running over a folder does not stack
# watermarks. Only used for files found in a folder - an explicitly named file
# is always processed.
is_own_output()
{
  local _basename _without_extension
  _basename=$(basename "$1")
  _without_extension="${_basename%.*}"
  case "$_without_extension" in
    *"_${file_name_postfix}") return 0;;
    *) return 1;;
  esac
}

# Return 0 if magick can read $1. Used to pick the images out of a folder -
# rather than guessing from the extension, magick gets to decide, so whatever
# the installed version supports works. -ping only reads the header.
#
# Note that this is deliberately "whatever magick can read", not "is a photo":
# a PDF or an SVG sitting in the folder will be watermarked too.
is_magick_readable()
{
  magick identify -ping "$1" >/dev/null 2>&1
}

# Watermark $1 into the folder $2 and report the outcome. Never aborts the run.
process_file()
{
  local _src="$1" _dest_dir="$2" _out _tmp_out _status
  [ -n "$_dest_dir" ] || _dest_dir="."
  if ! mkdir -p "$_dest_dir"; then
    echo "Error: ${_src}: could not create output folder '${_dest_dir}'."
    failed=$((failed + 1))
    return
  fi
  _out=$(build_output_path "$_src" "$_dest_dir")

  # Write to a temporary file first. magick can fail half way through and would
  # otherwise leave a truncated image behind - or destroy the result of an
  # earlier run. The extension is kept so magick still picks the right format.
  _tmp_out="${_out%.*}.wm-tmp-$$.${_out##*.}"

  watermark_file "$_src" "$_tmp_out"
  _status=$?
  if [ $_status -ne 0 ]; then
    rm -f "$_tmp_out"
    echo "Error: ${_src}: magick failed with exit code ${_status}; no output written."
    failed=$((failed + 1))
    return
  fi

  if ! mv -f "$_tmp_out" "$_out"; then
    rm -f "$_tmp_out"
    echo "Error: ${_src}: could not move the result to '${_out}'."
    failed=$((failed + 1))
    return
  fi

  processed=$((processed + 1))
  echo "Saved result to ${_out}"
}

# Watermark every image in the folder $1. Honours -r and -o.
process_dir()
{
  local _dir="${1%/}" _list _status _find_status _src _rel _rel_dir _dest_dir
  local _find_args _files
  _files=()

  # "${1%/}" turns "/" into an empty string, which find would choke on.
  [ -n "$_dir" ] || _dir="/"

  _list=$(mktemp "${TMPDIR:-/tmp}/wm.XXXXXX")
  _status=$?
  if [ $_status -ne 0 ] || [ -z "$_list" ]; then
    echo "Error: ${_dir}: could not create a temporary file."
    failed=$((failed + 1))
    return
  fi

  # -L follows symlinks. Without it find silently yields nothing at all when the
  # folder it is pointed at is a symlink.
  _find_args=( -L "$_dir" )
  [ "$is_recursive" = true ] || _find_args+=( -maxdepth 1 )
  _find_args+=( -type f -print0 )

  # Collect the complete list before processing anything: without -o the results
  # are written into the very folder being scanned, and find must not pick them
  # up as input again.
  find "${_find_args[@]}" >"$_list"
  _find_status=$?
  if [ $_find_status -ne 0 ]; then
    echo "Warning: ${_dir}: find exited with code ${_find_status}; some files may have been skipped."
  fi

  # is_own_output is a plain string check, is_magick_readable forks magick - so
  # weed out our own results first.
  while IFS= read -r -d '' _src; do
    is_own_output "$_src" && continue
    is_magick_readable "$_src" || continue
    _files+=( "$_src" )
  done <"$_list"
  rm -f "$_list"

  for _src in "${_files[@]}"; do
    if [ -z "$output_dir" ]; then
      _dest_dir=$(dirname "$_src")
    elif [ "$is_recursive" = true ]; then
      _rel="${_src#"$_dir"/}"
      _rel_dir=$(dirname "$_rel")
      if [ "$_rel_dir" = "." ]; then
        _dest_dir="$output_dir"
      else
        _dest_dir="${output_dir}/${_rel_dir}"
      fi
    else
      _dest_dir="$output_dir"
    fi

    process_file "$_src" "$_dest_dir"
  done
}

############################################################
############################################################
# Main program                                             #
############################################################
############################################################

main()
{
  # OPTIND is local so that main can be called more than once (the tests do).
  local OPTIND=1 option target

  # Initialize variables. These stay global on purpose - the helpers above read
  # them.
  text="Watermark"
  is_show_date=false
  is_recursive=false
  output_dir=""
  font_size=600
  date=$(date "+%d.%m.%Y")
  processed=0
  failed=0

  ############################################################
  # Process the input options. Add options as needed.        #
  ############################################################
  # Get the options
  while getopts "hdro:s:t:" option; do
     case $option in
        h) # display Help
           Help
           exit;;
        d) # add date to watermark
           is_show_date=true
           ;;
        r) # recurse into subfolders
           is_recursive=true
           ;;
        o) # set the output folder
           output_dir="${OPTARG%/}"
           ;;
        s) # set the font size
           font_size=$OPTARG
           ;;
        t) # Enter a name
           text=$OPTARG
           ;;
        *) # Invalid option
           echo "Error: Invalid option"
           exit 1;;
     esac
  done

  # Drop the options so that "$@" holds only the files and folders to process.
  shift $((OPTIND - 1))

  ############################################################
  # Validate the arguments.                                  #
  ############################################################

  if [ $# -lt 1 ]; then
      echo "$usage_string"
      exit 1
  fi

  if [ -n "$output_dir" ] && ! mkdir -p "$output_dir"; then
      echo "Error: could not create output folder '${output_dir}'."
      exit 1
  fi

  wm_text="${text}"
  file_name_postfix="${text// /-}"
  if [ "$is_show_date" = true ];
  then
    wm_text="${text}\n${date}"
    file_name_postfix="${file_name_postfix}-${date}"
  fi

  font=$(fc-match -f '%{file}' 2>/dev/null)

  ############################################################
  # Add watermark to the image(s) and save the result(s).    #
  ############################################################

  # Print a summary whenever more than one file can be involved.
  local is_batch=false
  if [ $# -gt 1 ]; then
    is_batch=true
  fi

  for target in "$@"; do
    if [ -d "$target" ]; then
      is_batch=true
      process_dir "$target"
    elif [ -f "$target" ]; then
      process_file "$target" "${output_dir:-$(dirname "$target")}"
    else
      echo "Error: '${target}' is not a file or a folder."
      case "$target" in
        -*) echo "       Options have to come before the files and folders.";;
      esac
      failed=$((failed + 1))
    fi
  done

  if [ "$is_batch" = true ]; then
    echo "Processed ${processed} file(s), ${failed} failed."
  fi

  [ $failed -eq 0 ] || exit 1
}

# Run only when executed. The test suite sources this file with
# WM_LIB_ONLY=true to get at the functions above without running anything.
if [ "${WM_LIB_ONLY:-false}" != true ]; then
  main "$@"
fi
