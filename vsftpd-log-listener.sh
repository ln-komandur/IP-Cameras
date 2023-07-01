#!/bin/bash

#https://stackoverflow.com/questions/48645159/how-to-extract-file-name-from-vsftpd-log-with-shell-script
#https://creativelycode.com/posts/a-linux-bash-script-to-recognize-when-a-file-is-added-to-ftp

function convert_H264_to_H265 ()
{
    H265_TS_Video="${2:0: -4}.ts" # .ts file name to save the output to .ts format at the destination path. It avoids overwriting source files.

    if [ -f "$H265_TS_Video" ];then # IF THERE IS A .ts file from an aborted conversion, delete it first. https://tecadmin.net/bash-script-check-if-file-is-empty-or-not/
        if [ -s "$H265_TS_Video" ];then
            echo [ "$(date +"%F %T")" ]: File "$H265_TS_Video" exists from previous attempts and is not empty. Deleting it to start conversion afresh
        else
	    echo [ "$(date +"%F %T")" ]: File "$H265_TS_Video" exists from previous attempts but is empty. Deleting it to start conversion afresh
        fi
	rm "$H265_TS_Video"
    fi

    echo [ "$(date +"%F %T")" ]: CONVERTING "$1" to "$H265_TS_Video"
    RESULT=$? # From https://unix.stackexchange.com/questions/22726/how-to-conditionally-do-something-if-a-command-succeeded-or-failed
    ffmpeg -i  "$1" -c:v libx265 -vtag hvc1 -loglevel quiet -x265-params log-level=quiet "$H265_TS_Video" <>/dev/null 2>&1 # ffmpeg conversion command . Quietened as in https://unix.stackexchange.com/questions/229390/bash-ffmpeg-libx265-prevent-output
    if [ $RESULT -eq 0 ]; then
        H265_MPG_Video="${H265_TS_Video%.*}.mpg"
        echo [ "$(date +"%F %T")" ]: SUCCESSFULLY converted "$1". RENAMING "$H265_TS_Video" to "$H265_MPG_Video"
        mv "$H265_TS_Video" "$H265_MPG_Video" # Change the file extension from .ts to .mpg in the same directory. This can be set up to send it to any directory.
        if [ $RESULT -eq 0 ]; then
            echo [ "$(date +"%F %T")" ]: RENAMED "$H265_TS_Video" to MPG file "$H265_MPG_Video"
	    if [ -f "$H265_MPG_Video" ];then # IF THERE IS A NON-EMPTY .mpg file, delete the mp4 file. https://tecadmin.net/bash-script-check-if-file-is-empty-or-not/
                if [ -s "$H265_MPG_Video" ];then
	             echo [ "$(date +"%F %T")" ]: FILE "$H265_MPG_Video" EXISTS AND IS NOT EMPTY. Deleting H.264 mp4 file
	             rm "$1"
	         else # Keep the mp4 file
	             echo [ "$(date +"%F %T")" ]: FILE "$H265_MPG_Video" EXISTS BUT IS EMPTY. Deleting it and moving the H.264 mp4 file to "$3"
	             rm "$H265_MPG_Video"
	             mv "$H265_MPG_Video" "$3"
                 fi
             else # Keep the mp4 file
	    	 echo [ "$(date +"%F %T")" ]: FILE "$H265_MPG_Video" DOES NOT EXIST. Moving the H.264 mp4 file to "$3"
	         mv "$H265_MPG_Video" "$3"
             fi
         else
             echo [ "$(date +"%F %T")" ]: FAILED to RENAME "$H265_TS_Video" to MPG file "$H265_MPG_Video"
         fi
     else
         echo [ "$(date +"%F %T")" ]: FAILED to convert "$1"
     fi
}

# This listener filters out successful uploads and then converts MP4 files from H.264 video codec to H.265 video codec and saves the latter as .MPG
# It runs the conversion activity as a separate process as in https://bash.cyberciti.biz/guide/Putting_functions_in_background so that it does not hold up the tail watch for other uploaded files
# Date format in time stamp is F - Full date, T - full time

ext_dr_mnt_pt=$1 # Mount point of external drive
base_folder=$2 # Base folder


echo [ "$(date +"%F %T")" ]: BEGIN LOGGING. DESTINATION ASKED AS "$ext_dr_mnt_pt"+"$base_folder"

tail -f -s 5 -n 1 /var/log/vsftpd.log | while read log_line; do
    if echo "$log_line" | grep -q 'OK UPLOAD:'; then # If there is a successful upload
        username=$(echo "$log_line" | sed -r 's/.*?\]\s\[(.+?)\].*?$/\1/') # Find out which user uploaded
        user_home=$(getent passwd "$username" | cut -d: -f6) # Get the home directory of that user. Refer https://superuser.com/questions/484277/get-home-directory-by-username
        file_at_rel_path=$(echo "$log_line" | sed -r 's/.*?\,\s\"(.+?)\".*?$/\1/') # Take everything within quotes in the log line. https://www.baeldung.com/linux/process-a-bash-variable-with-sed
        rel_path=$(echo "$file_at_rel_path" | sed -r 's/(^\/.+)*\/(.+)\.(.+)$/\1/') # Take everything from the first \/ and before the last \/ character in the log line. https://stackoverflow.com/questions/9363145/regex-for-extracting-filename-from-path
	echo [ "$(date +"%F %T")" ]: USERNAME is "$username" : USER HOME is "$user_home". SUCCESSFUL UPLOAD at "$user_home""$file_at_rel_path" # Log the full source path

        if [[ "$file_at_rel_path" == *.mp4 ]]; then # If this is an mp4 file

	    ## Get the path to the destination file - Begin
            destination_path="$user_home""$rel_path" # Default value if the external mount point is not mounted, or it is the same as the mount point of the users home
            destination_file="$user_home""$file_at_rel_path" # Default value if the external mount point is not mounted, or it is the same as the mount point of the users home

            ext_dr_mnt_status=false
            if mountpoint -q "$ext_dr_mnt_pt"; then # Check if the external drive is already / still mounted. Mounting it is out of scope of this shell script
                ext_dr_mnt_status=true
                echo [ "$(date +"%F %T")" ]: EXTERNAL DRIVE IS ALREADY / STILL MOUNTED. CREATING "$user_home""$base_folder" AND DOING mount --rbind
                mkdir -p  "$user_home""$base_folder"  # This helps ftp clients see the base_folder on the external mount point in the root folder of the ftp user 
                mount --rbind "$ext_dr_mnt_pt""$base_folder" "$user_home""$base_folder" # This helps ftp clients see the base_folder on the external mount point in the root folder of the ftp user
            else
                echo [ "$(date +"%F %T")" ]: EXTERNAL DRIVE IS NOT MOUNTED
            fi

            if $ext_dr_mnt_status && [[ $user_home != $ext_dr_mnt_pt ]]; then # Change destination_path if the external mount point is mounted, and is different from the mount point of the users home

                echo [ "$(date +"%F %T")" ]: CREATE DIRECTORY  mkdir -p "$ext_dr_mnt_pt""$base_folder""$rel_path"
                mkdir -p "$ext_dr_mnt_pt""$base_folder""$rel_path" # Create the directory

                if [ -d "$ext_dr_mnt_pt""$base_folder""$rel_path" ]; then # Check if the newly created path exists before pointing variables to it
                    destination_path="$ext_dr_mnt_pt""$base_folder""$rel_path"
                    destination_file="$ext_dr_mnt_pt""$base_folder""$file_at_rel_path"
                else
                    echo [ "$(date +"%F %T")" ]: NOT CHANGED DESTINATION PATH OR DESTINATION FILE
                fi
            fi
 	    ## Get the path to the destination file - End

            convert_H264_to_H265 "$user_home""$file_at_rel_path" "$destination_file" "$destination_path" & # Run the conversion as a separate process
        else
            echo [ "$(date +"%F %T")" ]: NOT AN MP4 FILE AT "$user_home""$file_at_rel_path"
        fi
    fi
done
