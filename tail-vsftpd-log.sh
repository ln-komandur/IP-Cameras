#!/bin/bash

#https://stackoverflow.com/questions/48645159/how-to-extract-file-name-from-vsftpd-log-with-shell-script
#https://creativelycode.com/posts/a-linux-bash-script-to-recognize-when-a-file-is-added-to-ftp

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
	else
	    echo "$full_file_path" is not an mp4 file
        fi
    fi
done
