#!/bin/bash
############################################################
# Help                                                     #
############################################################

usage_string="Usage: $(basename "$0") [-dhr] [-s size] [-t text] [-o outdir] (-i indir | file)"

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
   echo "i     Input folder. Watermark every image in it instead of a single file."
   echo "o     Output folder. Defaults to the folder of each input image."
   echo "r     Recurse into subfolders (only with -i). Mirrors the tree in the output folder."
   echo "s     Set the font size."
   echo "t     Set the text."
   echo
}

############################################################
############################################################
# Main program                                             #
############################################################
############################################################

# Initialize variables
text="Watermark"
is_show_date=false
is_recursive=false
input_dir=""
output_dir=""
font_size=600
date=$(date "+%d.%m.%Y")


############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts "hdri:o:s:t:" option; do
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
      i) # set the input folder
         input_dir="${OPTARG%/}"
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

input_file_path="${@:$OPTIND:1}"

############################################################
# Validate the arguments.                                  #
############################################################

if [ -n "$input_dir" ] && [ -n "$input_file_path" ]; then
    echo "Error: -i and a file argument are mutually exclusive."
    echo "$usage_string"
    exit 1
fi

if [ -z "$input_dir" ] && [ -z "$input_file_path" ]; then
    echo "$usage_string"
    exit 1
fi

if [ -n "$input_dir" ] && [ ! -d "$input_dir" ]; then
    echo "Error: input folder '${input_dir}' is not a directory."
    exit 1
fi

if [ "$is_recursive" = true ] && [ -z "$input_dir" ]; then
    echo "Warning: -r has no effect without -i; ignoring it."
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
# Helpers                                                  #
############################################################

# Build the output path for $1 (source file) inside $2 (target directory).
build_output_path()
{
  local _basename _without_extension _extension
  _basename=$(basename "$1")
  _without_extension="${_basename%.*}"
  _extension="${_basename##*.}"
  echo "${2}/${_without_extension}_${file_name_postfix}.${_extension}"
}

# Add the watermark to $1 and write the result to $2.
watermark_file()
{
  magick "$1" \
  \( -size ${font_size}x -background none -fill "#8339" -gravity center -font "${font}" \
  label:"${wm_text}" -trim -rotate -10 \
  -bordercolor none -border 5 \
  -write mpr:wm +delete \
  +clone -fill mpr:wm  -draw 'color 0,0 reset' \) \
  -compose over -composite \
  -strip \
  "$2"
}

# Return 0 if $1 has a known image extension.
is_image_file()
{
  local _basename _extension
  _basename=$(basename "$1")
  _extension="${_basename##*.}"
  case "$(echo "$_extension" | tr '[:upper:]' '[:lower:]')" in
    jpg|jpeg|png|tif|tiff|webp|heic|gif|bmp) return 0;;
    *) return 1;;
  esac
}

processed=0
failed=0

# Watermark $1 and report the outcome. Never aborts the run.
process_file()
{
  local _src="$1" _dest_dir="$2" _out _status
  if [ -n "$_dest_dir" ] && ! mkdir -p "$_dest_dir"; then
    echo "Error: ${_src}: could not create output folder '${_dest_dir}'."
    failed=$((failed + 1))
    return
  fi
  _out=$(build_output_path "$_src" "$_dest_dir")

  watermark_file "$_src" "$_out"
  _status=$?
  if [ $_status -ne 0 ]; then
    echo "Error: ${_src}: magick failed with exit code ${_status}; no output written."
    failed=$((failed + 1))
    return
  fi

  processed=$((processed + 1))
  echo "Saved result to ${_out}"
}

############################################################
# Add watermark to the image(s) and save the result(s).    #
############################################################

if [ -z "$input_dir" ]; then
  # Single file mode.
  dest_dir="$output_dir"
  [ -n "$dest_dir" ] || dest_dir=$(dirname "$input_file_path")
  process_file "$input_file_path" "$dest_dir"
else
  # Folder mode.
  find_args=( "$input_dir" )
  [ "$is_recursive" = true ] || find_args+=( -maxdepth 1 )
  find_args+=( -type f -print0 )

  while IFS= read -r -d '' src; do
    is_image_file "$src" || continue

    if [ -z "$output_dir" ]; then
      dest_dir=$(dirname "$src")
    elif [ "$is_recursive" = true ]; then
      rel="${src#"$input_dir"/}"
      rel_dir=$(dirname "$rel")
      if [ "$rel_dir" = "." ]; then
        dest_dir="$output_dir"
      else
        dest_dir="${output_dir}/${rel_dir}"
      fi
    else
      dest_dir="$output_dir"
    fi

    process_file "$src" "$dest_dir"
  done < <(find "${find_args[@]}")

  echo "Processed ${processed} file(s), ${failed} failed."
fi

[ $failed -eq 0 ] || exit 1
