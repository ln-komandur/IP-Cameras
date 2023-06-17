#!/bin/bash

#https://stackoverflow.com/questions/48645159/how-to-extract-file-name-from-vsftpd-log-with-shell-script
#https://creativelycode.com/posts/a-linux-bash-script-to-recognize-when-a-file-is-added-to-ftp

function convert_H264_to_H265 () 
{
    H265_TS_Video="${1:0: -4}.ts" # Name to save the output to .ts format. It is useful to not overwrite source files.
    rm "$H265_TS_Video" || true # IF THERE IS A .ts file from an aborted conversion, delete it first
    echo [ $(date +%s) ]: CONVERTING "$1" to "$H265_TS_Video" 
    RESULT=$? # From https://unix.stackexchange.com/questions/22726/how-to-conditionally-do-something-if-a-command-succeeded-or-failed
    ffmpeg -i  "$1" -c:v libx265 -vtag hvc1 -loglevel quiet -x265-params log-level=quiet "$H265_TS_Video" <>/dev/null 2>&1 # ffmpeg conversion command . Quietened as in https://unix.stackexchange.com/questions/229390/bash-ffmpeg-libx265-prevent-output
    if [ $RESULT -eq 0 ]; then
       echo [ $(date +%s) ]: SUCCESSFULLY converted "$1"
       echo [ $(date +%s) ]: RENAMING "$H265_TS_Video" to  "${H265_TS_Video%.*}.mpg" 
       mv "$H265_TS_Video" "${H265_TS_Video%.*}.mpg" # Change the file extension from .ts to .mpg in the same directory. This can be set up to send it to any directory.
       if [ $RESULT -eq 0 ]; then
           echo [ $(date +%s) ]: RENAMED "$H265_TS_Video" to MPG file "${H265_TS_Video%.*}.mpg"
           echo [ $(date +%s) ]: DELETING H.264 file "$1"
           rm "$1"
       else
           echo [ $(date +%s) ]: FAILED to RENAME "$H265_TS_Video" to MPG file "${H265_TS_Video%.*}.mpg"
       fi
    else
       echo [ $(date +%s) ]: FAILED to convert "$1"
    fi
}

#This listener filters out successful uploads and then converts MP4 files from H.264 video codec to H.265 video codec and saves the latter as .MPG
#It runs the conversion activity as a separate process as in https://bash.cyberciti.biz/guide/Putting_functions_in_background so that it does not hold up the tail watch for other uploaded files

echo [ $(date +%s) ]: LOGGING BEGINS

tail -f -s 5 -n 1 /var/log/vsftpd.log | while read line; do
    if echo "$line" | grep -q 'OK UPLOAD:'; then
        username=$(echo "$line" | sed -r 's/.*?\]\s\[(.+?)\].*?$/\1/')
        echo [ $(date +%s) ]: USERNAME is "$username"
        user_home=$(getent passwd "$username" | cut -d: -f6) # from https://superuser.com/questions/484277/get-home-directory-by-username
        echo [ $(date +%s) ]: USER HOME is "$user_home"

        filename=$(echo "$line" | sed -r 's/.*?\,\s\"(.+?)\".*?$/\1/') #https://www.baeldung.com/linux/process-a-bash-variable-with-sed
        echo  [ $(date +%s) ]: FILE SUCCESSFULLY UPLOADED is "$filename"
        full_file_path="$user_home""$filename"

        if [[ "$filename" == *mp4 ]]; then
            
	    echo  [ $(date +%s) ]: FULL PATH OF UPLOADED FILE is "$full_file_path"
            
            convert_H264_to_H265 "$full_file_path" "$conversion_log_file_path" & # Run the conversion as a separate process 
	else
	    echo [ $(date +%s) ]: NOT AN MP4 FILE AT "$full_file_path"
        fi
    fi
done
