#!/bin/bash

#https://stackoverflow.com/questions/48645159/how-to-extract-file-name-from-vsftpd-log-with-shell-script
#https://creativelycode.com/posts/a-linux-bash-script-to-recognize-when-a-file-is-added-to-ftp

function show_percent_savings()
{   # Refer https://superuser.com/questions/570908/calculate-difference-and-file-sizes-between-two-files
    mp4_file_size=$(stat -c%s "$1")
    mpg_file_size=$(stat -c%s "$2")
    percentage_savings=$(bc <<< "scale=2; ($mp4_file_size - $mpg_file_size)/$mp4_file_size * 100")
    echo PERCENTAGE SAVINGS "$percentage_savings %"
}

function convert_H264_to_H265 ()
{
    if [ -f "$1" ];then # If the H.264 mp4 source file exists, move it to the destination path first so that repeated attempts to convert it are preempted
        mv "$1" "$3"; # $3 is just the location of the directory
        echo [ "$(date +"%T")" ]: MOVED H.264 mp4 source file "$1" to "$3" # The full path and file name will now be the same as $2
    fi

    H265_TS_Video="${2:0: -4}.ts" # .ts file name to save the output to .ts format at the destination path. It avoids overwriting source files. $2 has the name of the directory and the file name too

    if [ -f "$H265_TS_Video" ];then # IF THERE IS A .ts file from an aborted conversion, delete it first. https://tecadmin.net/bash-script-check-if-file-is-empty-or-not/
        if [ -s "$H265_TS_Video" ];then
            echo [ "$(date +"%T")" ]: H265_TS_Video File "$H265_TS_Video" exists from previous attempts and is not empty. Deleting it to start conversion afresh
        else
	    echo [ "$(date +"%T")" ]: H265_TS_Video File "$H265_TS_Video" exists from previous attempts but is empty. Deleting it to start conversion afresh
        fi
	rm "$H265_TS_Video"
    fi

    echo [ "$(date +"%T")" ]: CONVERTING "$2" to "$H265_TS_Video"
    RESULT=$? # From https://unix.stackexchange.com/questions/22726/how-to-conditionally-do-something-if-a-command-succeeded-or-failed
    ffmpeg -i  "$2" -c:v libx265 -vtag hvc1 -loglevel quiet -x265-params log-level=quiet "$H265_TS_Video" <>/dev/null 2>&1 # ffmpeg conversion command . Quietened as in https://unix.stackexchange.com/questions/229390/bash-ffmpeg-libx265-prevent-output
    if [ $RESULT -eq 0 ]; then
        H265_MPG_Video="${H265_TS_Video%.*}.mpg" # Same name as TS file but with mpg extension
        echo [ "$(date +"%T")" ]: CONVERTED "$2". RENAMING "$H265_TS_Video" to "$H265_MPG_Video"
        mv "$H265_TS_Video" "$H265_MPG_Video" # Change the file extension from .ts to .mpg in the same directory. This can be set up to send it to any directory.
        if [ $RESULT -eq 0 ]; then
            echo [ "$(date +"%T")" ]: RENAMED "$H265_TS_Video" to MPG file "$H265_MPG_Video"

	    # IF THERE IS A NON-EMPTY .mpg file, delete the mp4 file if the keep_source parameter is not set. https://tecadmin.net/bash-script-check-if-file-is-empty-or-not/

            if [ -f "$H265_MPG_Video" ]; then # IF THERE IS A H265_MPG_Video file
                if [ -s "$H265_MPG_Video" ]; then # IF H265_MPG_Video is not empty
	            echo -n [ "$(date +"%T")" ]: SUCCESSFULLY CONVERTED to H265_MPG_Video. "$H265_MPG_Video" EXISTS AND IS NOT EMPTY. # echo -n skips the trailing newline
	            show_percent_savings "$2" "$H265_MPG_Video"
	            if [ $4 != "Y" ]; then # Dont want to keep the H.264 mp4 source file
	                echo [ "$(date +"%T")" ]: Deleting H.264 mp4 file "$2"
	                rm "$2"
		    else # This keeps both the non-zero H.265 mpg file as well as the H.264 mp4 source file
      	                echo [ "$(date +"%T")" ]: KEEPING H.264 mp4 file moved to "$2"
		    fi
	        else # H265_MPG_Video is empty. Keep the mp4 file and move it to the destination path
	            echo [ "$(date +"%T")" ]: H265_MPG_Video FILE "$H265_MPG_Video" EXISTS BUT IS EMPTY. Deleting it.
                    echo [ "$(date +"%T")" ]: KEEPING H.264 mp4 file moved to "$2"
                    rm "$H265_MPG_Video"
                fi
            else # H265_MPG_Video does not exist. Keep the mp4 file and move it to the destination path
	    	echo [ "$(date +"%T")" ]: H265_MPG_Video FILE "$H265_MPG_Video" DOES NOT EXIST.
                echo [ "$(date +"%T")" ]: KEEPING H.264 mp4 file moved to "$2"
            fi
        else
            echo [ "$(date +"%T")" ]: FAILED to RENAME "$H265_TS_Video" to MPG file "$H265_MPG_Video"
        fi
    else
        echo [ "$(date +"%T")" ]: FAILED to convert "$2"
    fi
}

# This listener filters out successful uploads and then converts MP4 files from H.264 video codec to H.265 video codec and saves the latter as .MPG
# It runs the conversion activity as a separate process as in https://bash.cyberciti.biz/guide/Putting_functions_in_background so that it does not hold up the tail watch for other uploaded files
# Date format in time stamp is F - Full date, T - full time

ext_dr_mnt_pt=$1 # Mount point of external drive
base_folder=$2 # Base folder
keep_source=$3 # Whether to keep the H.264 source .mp4 file after conversion

echo [ "$(date +"%F %T")" ]: -------- BEGIN LOGGING --------. DESTINATION ASKED AS "$ext_dr_mnt_pt" + "$base_folder"

# https://unix.stackexchange.com/questions/12075/best-way-to-follow-a-log-and-execute-a-command-when-some-text-appears-in-the-log
# -F to handle log rotation - i.e. my.log becomes full and moves to my.log.1
tail -F /var/log/vsftpd.log | grep --line-buffered -Po "^.+?OK\sUPLOAD.+?.\mp4.+?$" | while read -r log_line ; do  # Get at least one successful mp4 upload

    file_at_rel_path=$(echo "$log_line" | sed -r 's/.*?\,\s\"(.+?)\".*?$/\1/') # Take everything within quotes in the log line. https://www.baeldung.com/linux/process-a-bash-variable-with-sed
    user_name=$(echo "$log_line" | sed -r 's/.*?\]\s\[(.+?)\].*?$/\1/') # Find out which user uploaded
    user_home=$(getent passwd "$user_name" | cut -d: -f6) # Get the home directory of that user. Refer https://superuser.com/questions/484277/get-home-directory-by-username
    rel_path=$(echo "$file_at_rel_path" | sed -r 's/(^\/.+)*\/(.+)\.(.+)$/\1/') # Take everything from the first \/ and before the last \/ character in the file at relative path. https://stackoverflow.com/questions/9363145/regex-for-extracting-filename-from-path

    echo [ "$(date +"%F %T")" ]: TRIGGERED BASED ON FILE UPLOADED AT PATH "$user_home""$file_at_rel_path". SLEEPING 120 seconds
    destination_path="$user_home""$rel_path" # Default value if the external mount point is not mounted, or it is the same as the mount point of the users home

    sleep 120 # Sleep for 2 minutes for any pending writes to be completed. This helps to catch the last mp4 file of the day, as the same folder will not be looked at again. The next day, the script will work on a different date folder. Without sleep, the last file of a day will get skipped / looked over

    ## Set the path to the destination file - Begin
    if mountpoint -q "$ext_dr_mnt_pt"; then # Check if the external drive is already / still mounted
        echo [ "$(date +"%T")" ]: EXTERNAL MOUNT POINT $ext_dr_mnt_pt is ALREADY / STILL MOUNTED.
	if [[ $user_home != $ext_dr_mnt_pt ]]; then # and if the external mount point is different from the mount point of the users home
            # Mounting external drive is out of scope of this shell script. It has to be done in /etc/fstab
	    # Change destination_path to the external mount point
	    destination_path="$ext_dr_mnt_pt""$base_folder""$rel_path" # Change the destination path to the external mount point

	    echo [ "$(date +"%T")" ]: CREATING DIRECTORY  in the external mount point - mkdir -p "$destination_path"
            mkdir -p "$destination_path" # Create directory in the external mount point

            echo [ "$(date +"%T")" ]: CREATING "$base_folder" in "$user_home" AND DOING mount --rbind to "$ext_dr_mnt_pt""$base_folder"
            mkdir -p  "$user_home""$base_folder"  # This helps ftp clients see the base_folder on the external mount point in the root folder of the ftp user
            mount --rbind "$ext_dr_mnt_pt""$base_folder" "$user_home""$base_folder" # This helps ftp clients see the base_folder on the external mount point in the root folder of the ftp user
        else
            echo [ "$(date +"%T")" ]: NOT CHANGED DESTINATION PATH. EXTERNAL DRIVE MAY NOT BE MOUNTED, OR IS THE SAME AS THE USERs HOME
        fi
    else
        echo [ "$(date +"%T")" ]: EXTERNAL MOUNT POINT is NOT MOUNTED
    fi
    ## Set the path to the destination file - End

    all_pending_mp4_files="$user_home""$rel_path""/*.mp4"
    echo [ "$(date +"%T")" ]: FINDING ALL MP4 files at "$all_pending_mp4_files" PENDING CONVERSION

    for mp4_src_file_name in $all_pending_mp4_files
    do
        echo [ "$(date +"%T")" ]: CHECKING IF "$mp4_src_file_name" can be converted now # Log the full source path
        if  test `find "$mp4_src_file_name" -mmin +2`; then # Is this file more than 2 minutes old. If not, it  is perhaps still being written to
            echo [ "$(date +"%T")" ]: CAN CONVERT "$mp4_src_file_name" as it more than 2 minutes old
            file_name_only=$(echo "$mp4_src_file_name" | sed -r 's/(^\/.+)*(\/.+\..+)$/\2/') # Take everything after the last \/, including it, till the end in the mp4 file name. https://stackoverflow.com/questions/9363145/regex-for-extracting-filename-from-path
            destination_file="$destination_path""$file_name_only"

            echo [ "$(date +"%T")" ]: DESTINATION OF MP4 FILE post conversion will be "$destination_file"
	    convert_H264_to_H265 "$mp4_src_file_name" "$destination_file" "$destination_path" "$keep_source" & # Run the conversion as a separate process
        else
            echo [ "$(date +"%T")" ]: MP4 SOURCE FILE "$mp4_src_file_name" is less than 2 minutes old. Perhaps still BEING WRITTEN TO or IS ALREADY CONVERTED AND NOT THERE
        fi
    done
done
