#!/bin/bash

#https://stackoverflow.com/questions/48645159/how-to-extract-file-name-from-vsftpd-log-with-shell-script
#https://creativelycode.com/posts/a-linux-bash-script-to-recognize-when-a-file-is-added-to-ftp

function convert_H264_to_H265 () 
{
    H265_TS_Video="${2:0: -4}.ts" # .ts file name to save the output to .ts format at the destination path. It avoids overwriting source files.
    rm "$H265_TS_Video" || true # IF THERE IS A .ts file from an aborted conversion, delete it first. Refer https://superuser.com/questions/76061/how-do-i-make-rm-not-give-an-error-if-a-file-doesnt-exist
    echo [ "$timestamp" ]: CONVERTING "$1" to "$H265_TS_Video" 
    RESULT=$? # From https://unix.stackexchange.com/questions/22726/how-to-conditionally-do-something-if-a-command-succeeded-or-failed
    ffmpeg -i  "$1" -c:v libx265 -vtag hvc1 -loglevel quiet -x265-params log-level=quiet "$H265_TS_Video" <>/dev/null 2>&1 # ffmpeg conversion command . Quietened as in https://unix.stackexchange.com/questions/229390/bash-ffmpeg-libx265-prevent-output
    if [ $RESULT -eq 0 ]; then
       H265_MPG_Video="${H265_TS_Video%.*}.mpg" 
       echo [ "$timestamp" ]: SUCCESSFULLY converted "$1"
       echo [ "$timestamp" ]: RENAMING "$H265_TS_Video" to  "$H265_MPG_Video" 
       mv "$H265_TS_Video" "$H265_MPG_Video" # Change the file extension from .ts to .mpg in the same directory. This can be set up to send it to any directory.
       if [ $RESULT -eq 0 ]; then
           echo [ "$timestamp" ]: RENAMED "$H265_TS_Video" to MPG file "$H265_MPG_Video"
           echo [ "$timestamp" ]: DELETING H.264 file "$1"
           rm "$1"
       else
           echo [ "$timestamp" ]: FAILED to RENAME "$H265_TS_Video" to MPG file "$H265_MPG_Video"
       fi
    else
       echo [ "$timestamp" ]: FAILED to convert "$1"
    fi
}

# This listener filters out successful uploads and then converts MP4 files from H.264 video codec to H.265 video codec and saves the latter as .MPG
# It runs the conversion activity as a separate process as in https://bash.cyberciti.biz/guide/Putting_functions_in_background so that it does not hold up the tail watch for other uploaded files

timestamp="$(date +"%F %T")"
ext_dr_mnt_pt=$1 # Mount point of external drive
base_folder=$2 # Base folder

ext_dr_mnt_status=false

if mountpoint -q "$ext_dr_mnt_pt"; then # Check if the external drive is already mounted. Mounting it is out of scope of this shell script
    ext_dr_mnt_status=true
fi 

echo [ "$timestamp" ]: BEGIN LOGGING # Date format is F - Full date, T - full time

tail -f -s 5 -n 1 /var/log/vsftpd.log | while read log_line; do
    if echo "$log_line" | grep -q 'OK UPLOAD:'; then # If there is a successful upload
        username=$(echo "$log_line" | sed -r 's/.*?\]\s\[(.+?)\].*?$/\1/') # Find out which user uploaded
        user_home=$(getent passwd "$username" | cut -d: -f6) # from https://superuser.com/questions/484277/get-home-directory-by-username
        echo [ "$timestamp" ]: USERNAME is "$username" : USER HOME is "$user_home"
        file_at_rel_path=$(echo "$log_line" | sed -r 's/.*?\,\s\"(.+?)\".*?$/\1/') # Take everything within quotes. https://www.baeldung.com/linux/process-a-bash-variable-with-sed                     
        rel_path=$(echo "$file_at_rel_path" | sed -r 's/(^\/.+)*\/(.+)\.(.+)$/\1/') # Take everything from the first \/ and before the last \/ character. # https://stackoverflow.com/questions/9363145/regex-for-extracting-filename-from-path
        echo [ "$timestamp" ]: SUCCESSFUL UPLOAD at "$user_home""$file_at_rel_path" # Log the full source path
      
        if [[ "$file_at_rel_path" == *.mp4 ]]; then # If this is an mp4 file
            destination_path="$user_home""$rel_path" # Default value if the external mount point is not mounted, or it is the same as the mount point of the users home
            destination_file="$user_home""$file_at_rel_path" # Default value if the external mount point is not mounted, or it is the same as the mount point of the users home

            if $ext_dr_mnt_status && [[ $user_home != $ext_dr_mnt_pt ]]; then # Change destination_path if the external mount point is mounted, and is different from the mount point of the users home
                destination_path="$ext_dr_mnt_pt""$base_folder""$rel_path"
                destination_file="$ext_dr_mnt_pt""$base_folder""$file_at_rel_path" 
                echo [ "$timestamp" ]: CREATE DIRECTORY  mkdir -p "$destination_path"
                mkdir -p "$destination_path"
            fi
 
            convert_H264_to_H265 "$user_home""$file_at_rel_path" "$destination_file" & # Run the conversion as a separate process 
        else
            echo [ "$timestamp" ]: NOT AN MP4 FILE AT "$user_home""$file_at_rel_path"
        fi
    fi
done
