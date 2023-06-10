#!/bin/bash

# Adapted from https://stackoverflow.com/questions/56717674/code-must-find-all-mp4-files-within-subdirectory-to-compress-using-ffmpeg
# This script can take the name of the directory under which recursive conversion needs to be done as an argument. If no arguments are given, conversion will begin with the directory where this script is executed from


# Define the function to convert H264 to H265
H264_to_H265() {
    cd "$1" # Change to a directory only if an argument is passed. The first call will not have it, and will therefore be the directory where the script is executed from
    echo pwd is $PWD
    for listed_name in *; do # Find all files and directories
        if [[ -d "$listed_name" ]]; then # If the name is a directory. i.e. there is a directory by this name
	    echo "This is a directory. Its name is " ${listed_name}
            H264_to_H265 "$listed_name" # Recurse into that directory
        elif [[ "$listed_name" == *.mp4 ]]; then # If the name is an mp4 file
            echo "This is an mp4 file. Its directory is" ${PWD}
            echo "File name with ts is" ${listed_name%.*}.ts
            
            H265_TS_Video="${listed_name:0: -4}.ts" # Saving the output to .ts format, is useful to not overwrite source files.
            echo Converting "$listed_name" to "$H265_TS_Video"     # run your command here
            RESULT=$? # From https://unix.stackexchange.com/questions/22726/how-to-conditionally-do-something-if-a-command-succeeded-or-failed
            ffmpeg -i "$listed_name" -c:v libx265 -vtag hvc1 "$H265_TS_Video"
 	    if [ $RESULT -eq 0 ]; then
	       echo CONVERTED
	       echo Renaming "$H265_TS_Video" to  "${H265_TS_Video%.*}.mpg" # Rename the ts file as mpg file
	       mv "$H265_TS_Video" "${H265_TS_Video%.*}.mpg" # Converts the file extension to MPG in the same directory. This can be set up to send it to any directory.
	       if [ $RESULT -eq 0 ]; then
	           echo RENAMED TS to MPG. Deleting H.264
	           rm "$listed_name"
	       else
	           echo FAILED to rename
	       fi
	    else
	       echo FAILED to convert
	    fi
        fi
    done
    cd .. # Go one level up to traverse sibling directories
} # End of function definition


# Main call below

H264_to_H265 $1 # Call the function for THE FIRST CALL here. If a directory is originally passed as an argument, then use it here

exit
