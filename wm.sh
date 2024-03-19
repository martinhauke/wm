#!/bin/sh
############################################################
# Help                                                     #
############################################################

usage_string="Usage: `basename $0` [-dh] [-s size] [-t text] file"

Help()
{
   # Display Help
   echo "Add watermarks to an image."
   echo
   echo $usage_string
   echo
   echo "Options:"
   echo "d     Add the current date to the watermark."
   echo "h     Print this Help."
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
font_size=600
date=$(date "+%d.%m.%Y")


############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts "hds:t:" option; do
   case $option in
      h) # display Help
         Help
         exit;;
      d) # add date to watermark
         is_show_date=true
         ;;
      s) # set the font size
         font_size=$OPTARG
         ;;
      t) # Enter a name
         text=$OPTARG
         ;;
      *) # Invalid option
         echo "Error: Invalid option"
         exit;;
   esac
done

if [ $(( $# - $OPTIND )) -lt 0 ]; then
    echo $usage_string
    exit 1
fi


wm_text="${text}"
file_name_postfix="${text// /-}"
if [ "$is_show_date" == true ];
then
  wm_text="${text}\n${date}"
  file_name_postfix="${file_name_postfix}-${date}"
fi

input_file_path=${@:$OPTIND:1}
_input_file_dirname=$(dirname $input_file_path)
_input_file_basename=$(basename $input_file_path)
_input_file_basename_without_extension="${_input_file_basename%.*}"
_input_file_extension="${_input_file_basename##*.}"

output_file_path="${_input_file_dirname}/${_input_file_basename_without_extension}_${file_name_postfix}.${_input_file_extension}"

############################################################
# Add watermark to image and save the result.              #
############################################################

convert ${input_file_path} \
\( -size ${font_size}x -background none -fill "#8339" -gravity center \
label:"${wm_text}" -trim -rotate -10 \
-bordercolor none -border 5 \
-write mpr:wm +delete \
+clone -fill mpr:wm  -draw 'color 0,0 reset' \) \
-compose over -composite \
-strip \
${output_file_path}

echo "Saved result to ${output_file_path}"
