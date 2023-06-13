#!/bin/bash

#https://stackoverflow.com/questions/48645159/how-to-extract-file-name-from-vsftpd-log-with-shell-script
#https://creativelycode.com/posts/a-linux-bash-script-to-recognize-when-a-file-is-added-to-ftp

function convert_H264_to_H265 () 
{
    H265_TS_Video="${1:0: -4}.ts" # Saving the output to .ts format, is useful to not overwrite source files.
    echo Converting "$1" to "$H265_TS_Video"     # run your command here
    RESULT=$? # From https://unix.stackexchange.com/questions/22726/how-to-conditionally-do-something-if-a-command-succeeded-or-failed
    ffmpeg -i "$1" -c:v libx265 -vtag hvc1 "$H265_TS_Video"
    if [ $RESULT -eq 0 ]; then
       echo CONVERTED
       echo Renaming "$H265_TS_Video" to  "${H265_TS_Video%.*}.mpg" # Rename the ts file as mpg file
       mv "$H265_TS_Video" "${H265_TS_Video%.*}.mpg" # Converts the file extension to MPG in the same directory. This can be set up to send it to any directory.
       if [ $RESULT -eq 0 ]; then
           echo RENAMED TS to MPG. Deleting H.264
           rm "$1"
       else
           echo FAILED to rename
       fi
    else
       echo FAILED to convert
    fi
}

#This listener filters out successful uploads and then converts MP4 files from H.264 video codec to H.265 video codec and saves the latter as .MPG
#It (strives to) runs the conversion activity as a separate process

tail -f -s 5 -n 1 /var/log/vsftpd.log | while read line; do
    if echo "$line" | grep -q 'OK UPLOAD:'; then
        username=$(echo "$line" | sed -r 's/.*?\]\s\[(.+?)\].*?$/\1/')
        echo user name is "$username"
        user_home=$(getent passwd "$username" | cut -d: -f6) # from https://superuser.com/questions/484277/get-home-directory-by-username
        echo user home is "$user_home"

        filename=$(echo "$line" | sed -r 's/.*?\,\s\"(.+?)\".*?$/\1/') #https://www.baeldung.com/linux/process-a-bash-variable-with-sed
        echo tail line file name is "$filename"
        full_file_path="$user_home""$filename"

        if [[ "$filename" == *mp4 ]]; then
            
	    echo An mp4 file is uploaded at "$full_file_path"
            #https://bash.cyberciti.biz/guide/Putting_functions_in_background
            convert_H264_to_H265 "$full_file_path" & # Run the conversion as a separate process so that the conversion itself does not hold up the tail watch for other mp4 files getting uploaded
	else
	    echo "$full_file_path" is not an mp4 file
        fi
    fi
done
