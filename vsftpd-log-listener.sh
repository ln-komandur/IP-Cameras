#!/bin/bash

#https://stackoverflow.com/questions/48645159/how-to-extract-file-name-from-vsftpd-log-with-shell-script
#https://creativelycode.com/posts/a-linux-bash-script-to-recognize-when-a-file-is-added-to-ftp

function convert_H264_to_H265 () 
{
    H265_TS_Video="${3:0: -4}.ts" # Name to save the output to .ts format. It is useful to not overwrite source files.
    rm "$2""$H265_TS_Video" || true # IF THERE IS A .ts file from an aborted conversion, delete it first. Refer https://superuser.com/questions/76061/how-do-i-make-rm-not-give-an-error-if-a-file-doesnt-exist
    echo [ "$timestamp" ]: CONVERTING "$1""$3" to "$2""$H265_TS_Video" 
    RESULT=$? # From https://unix.stackexchange.com/questions/22726/how-to-conditionally-do-something-if-a-command-succeeded-or-failed
    ffmpeg -i  "$1""$3" -c:v libx265 -vtag hvc1 -loglevel quiet -x265-params log-level=quiet "$2""$H265_TS_Video" <>/dev/null 2>&1 # ffmpeg conversion command . Quietened as in https://unix.stackexchange.com/questions/229390/bash-ffmpeg-libx265-prevent-output
    if [ $RESULT -eq 0 ]; then
       echo [ "$timestamp" ]: SUCCESSFULLY converted "$1""$3"
       echo [ "$timestamp" ]: RENAMING "$2""$H265_TS_Video" to  "$2""${H265_TS_Video%.*}.mpg" 
       mv "$2""$H265_TS_Video" "$2""${H265_TS_Video%.*}.mpg" # Change the file extension from .ts to .mpg in the same directory. This can be set up to send it to any directory.
       if [ $RESULT -eq 0 ]; then
           echo [ "$timestamp" ]: RENAMED "$2""$H265_TS_Video" to MPG file "$2""${H265_TS_Video%.*}.mpg"
           echo [ "$timestamp" ]: DELETING H.264 file "$1""$3"
           rm "$1""$3"
       else
           echo [ "$timestamp" ]: FAILED to RENAME "$2""$H265_TS_Video" to MPG file "$2""${H265_TS_Video%.*}.mpg"
       fi
    else
       echo [ "$timestamp" ]: FAILED to convert "$1""$3"
    fi
}

#This listener filters out successful uploads and then converts MP4 files from H.264 video codec to H.265 video codec and saves the latter as .MPG
#It runs the conversion activity as a separate process as in https://bash.cyberciti.biz/guide/Putting_functions_in_background so that it does not hold up the tail watch for other uploaded files

timestamp="$(date +"%F %T")"
ext_dr_mnt_pt="/dev/sda6" # Mount point of external drive

ext_dr_mnt_stat=false

if mount "$ext_dr_mnt_pt"; then # Try to mount the external drive once and know the status
    ext_dr_mnt_stat=true
fi 

tail -f -s 5 -n 1 /var/log/vsftpd.log | while read log_line; do
    if echo "$log_line" | grep -q 'OK UPLOAD:'; then
    
    	username=$(echo "$log_line" | sed -r 's/.*?\]\s\[(.+?)\].*?$/\1/')
	echo [ "$timestamp" ]: BEGIN LOGGING # Date format is F - Full date, T - full time
	echo [ "$timestamp" ]: USERNAME is "$username"
	user_home=$(getent passwd "$username" | cut -d: -f6) # from https://superuser.com/questions/484277/get-home-directory-by-username
	echo [ "$timestamp" ]: USER HOME is "$user_home"
    
    	file_rel_path=$(echo "$log_line" | sed -r 's/.*?\,\s\"(.+?)\".*?$/\1/') # Take everything within quotes. https://www.baeldung.com/linux/process-a-bash-variable-with-sed
    	  	
   	rel_path=$(echo "$file_rel_path" | sed -r 's/(^\/.+\/)*(.+)\.(.+)$/\1/') # Take everything between the first \/ and the last \/ character. # https://stackoverflow.com/questions/9363145/regex-for-extracting-filename-from-path
        echo  [ "$timestamp" ]: SUCCESSFUL UPLOAD at "$user_home""$file_rel_path"

        if ! $ext_dr_mnt_stat; then # If the drive is not mounted, then use the user home
	    ext_dr_mnt_pt="$user_home"
	else
	    echo [ "$timestamp" ]: CREATE DIRECTORY  mkdir -p "$ext_dr_mnt_pt""$rel_path"
	    mkdir -p "$ext_dr_mnt_pt""$rel_path"
        fi
        
        if [[ "$file_rel_path" == *mp4 ]]; then # If this is an mp4 file
            
            convert_H264_to_H265 "$user_home" "$ext_dr_mnt_pt" "$file_rel_path" & # Run the conversion as a separate process 
	else
	    echo [ "$timestamp" ]: NOT AN MP4 FILE AT "$user_home""$file_rel_path"
        fi
    fi
done
