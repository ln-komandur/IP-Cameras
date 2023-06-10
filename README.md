# IP-Cameras
## Introduction / Purpose
Leverage the **FTPs** capability offered by a few Security IP cameras, and upload motion video clips and photos to a local linux ftp server (that has TLS enabled). Physically isolate the set-up from the internet unless otherwise desired.

## Hardware
1.   Reolink - RLC-510WA
2.   Desktop to run Ubuntu 22.04, with reasonable storage to store video clips and photos from multiple IP cameras
3.   Dualband wifi router with RJ45 and reasonable bandwidth to use the less congested 5GHz band 
4.   Display dummy (HDMI / DisplayPort) to use the linux box headless

## Software
1.   Ubuntu 22.04 desktop
2.   vsftpd
3.   Filezilla
4.   Reolink [RLC-510WA firmware version 1.0.280 (1387_22100633)](https://support.reolink.com/attachments/token/1ISbkfiJ3uJ2rganejlK6JUvG/?name=IPC_523128M5MP.1387_22100633.RLC-510WA.OV05A10.5MP.WIFI1021.REOLINK.pak)


## References

1.   https://www.programbr.com/ubuntu/how-to-install-ftp-server-vsftpd-on-ubuntu/
2.   https://unix.stackexchange.com/questions/654625/setting-up-vsftp
3.   https://www.reddit.com/r/reolinkcam/comments/10iv3di/question_my_rlc510wa_cannot_connect_to_filezilla/ - has the link to the correct firmware version to support **FTPs**
4.   https://docs.openeuler.org/en/docs/20.09/docs/Administration/configuring-the-ftp-server.html - Explains the parameters to configure vsftpd

## On ubuntu desktop

### BIOS
Use relevant settings to automatically power on after a power failure

### Install vsftpd

`sudo apt install nala` # *Use nala to install other software*

`sudo nala update`

`sudo nala install filezilla` # *Install filezilla*

`sudo nala install vsftpd` # *Install vsftpd*

`sudo service vsftpd status` # *Check if vsftpd service is active/running*

`vsftpd -v` # *Check the version of vsftpd*

`hostname` # *Get the hostname to provide in Filezilla for test and to provide in each IP Camera*


### Configure ufw

`sudo ufw status` #*Check the firewall's status. Could be inactive*

`sudo ufw allow 20/tcp` # *Open port 20 (FTP data port)*

`sudo ufw allow 21/tcp` # *Open port 21 (FTP command port)*

`sudo ufw allow 40000:50000/tcp` # *Open ports 40000-50000 for the range of passive FTP*

`sudo ufw allow 990/tcp` # *Open port 990 for TLS*

`sudo nala install ssh` # *Install ssh if not already installed*

`sudo ufw allow OpenSSH` # *Allow OpenSSH*

`sudo ufw disable && sudo ufw enable` # *Disable and enable UFW*

`sudo ufw status` # *Check if UFW is active*


### ftp user id
`sudo adduser ipcamera` # *Add a user just to ftp photos and video clips from ip cameras*

`echo "cameras" | sudo tee -a /etc/vsftpd.userlist` # *Add that user to the list of users who can use vsftpd*

`cat /etc/vsftpd.userlist` # *Check if the user is added to the list of users who can use vsftpd*

### Generate certificate
`sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/vsftpd.pem -out /etc/ssl/private/vsftpd.pem` # *generate a 2048-bit RSA key and self-signed SSL certificate that will be valid for 365 days*


### Configure vsftpd
`sudo nano /etc/vsftpd.conf` # *Open the conf file*

Edit as needed for the following fields and values
```
anonymous_enable=NO
local_enable=YES
write_enable=YES

chroot_local_user=YES
allow_writeable_chroot=YES
pasv_min_port=40000
pasv_max_port=50000

rsa_cert_file=/etc/ssl/private/vsftpd.pem
rsa_private_key_file=/etc/ssl/private/vsftpd.pem
ssl_enable=YES

userlist_enable=YES
userlist_file=/etc/vsftpd.userlist
userlist_deny=NO
userlist_deny=NO
```

**Optional**

`listen_ipv6=NO` # *May not use IPv6*


**Not sure**

`listen = YES` # Refer [this link](https://www.ibiblio.org/pub/Linux/docs/linux-doc-project/linuxfocus/English/Archives/lf-2004_07-0341.pdf) on using standalone mode or not

### Restart vsftpd
`sudo systemctl restart vsftpd` # *Restart vsftpd for changes to take effect*


### Testing with filezilla
1.  Test using `hostname` to connect
2.  Test using intranet ip address
3.  Test using 'ipcamera' user credentials to see if connections are successful
4.  Test using other user credentials to see if connections are unsuccessful
5.  Test if TLS is working (from the certificate shown as well as login messages)
6.  Test if directories are resrticted. i.e. cannot traverse above home directory
7.  Test if downloading from ftp location to local location is working

### Testing with Headless operation mode
Plug in the display dummy (in the HDMI or DisplayPort) and test ftp from a client on a different machine


### Testing ftp before any user logs into the desktop
This simulates a power failure situation

### Batch job to recode each video clip from H.264 to H.265
TBD - using ffmpeg commands in a shell script and executing them on schedule as a cronjob

***Questions:*** 
1.  How will the cronjob run if no user has logged in when recovering from a power failure. Will this be the `sudo` user or the `ipcamera` user? 
    1.  [Look here for pointers to both questions](https://unix.stackexchange.com/questions/197615/does-a-job-scheduled-in-crontab-run-even-when-i-log-out)  
2.  What are the security issues (of running without logging in, and as which user the job runs as)?

### Use an external drive to store H.265 video clips
This is to save space on the internal drive
1.  Keep photos on local drive as well as external drive (i.e. in case the external drive is lost / stolen)
2.  Keep only H.265 video clips on external drive
3.  Do not keep any video clips on local drive after the recoding is successful (keep only if external drive is not connected) 
4.  Ensure that the external drive is automatically mounted upon power on with mount point entries in `/etc/fstab`
5.  Ensure that the `sudo` user (not `ipcamera` user) has all permissions to write to the external drive. This is usually so, but just ensure that it is happening.  See ***Questions under recoding each video clip***

Save the below shell script as `H264_to_H265.sh`. Each H.265 video will be stored in the same directory as a .mpg file

```
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
            ffmpeg -i "$listed_name" -c:v libx265 -vtag hvc1 "$H265_TS_Video"
            
	    echo Renaming "$H265_TS_Video" to  "${H265_TS_Video%.*}.mpg" # Rename the ts file as mpg file
	    mv "$H265_TS_Video" "${H265_TS_Video%.*}.mpg" # Converts the file extension to MPG in the same directory. This can be set up to send it to any directory.

        fi
    done
    cd .. # Go one level up to traverse sibling directories
} # End of function definition


# Main call below

H264_to_H265 $1 # Call the function for THE FIRST CALL here. If a directory is originally passed as an argument, then use it here
```
`chmod +x H264_to_H265.sh` # *Permit executing the script*

Refer [this for the command to convert videos one at a time](https://stackoverflow.com/questions/58742765/convert-videos-from-264-to-265-hevc-with-ffmpeg)

Refer [this to find all MP4 files within subdirectory to compress using ffmpeg](https://stackoverflow.com/questions/56717674/code-must-find-all-mp4-files-within-subdirectory-to-compress-using-ffmpeg)

Refer [this to do a batch conversion but in the reverse direction](https://askubuntu.com/questions/707397/batch-convert-h-265-mkv-to-h-264-with-ffmpeg-to-make-files-compatible-for-re-enc). This covers `.ts` file extensions


## On each IP Camera (RLC-510WA)

1.  Update firmware to version 1.0.280 so that the camera can use ftps (protocol) - this is available [here](https://support.reolink.com/attachments/token/1ISbkfiJ3uJ2rganejlK6JUvG/?name=IPC_523128M5MP.1387_22100633.RLC-510WA.OV05A10.5MP.WIFI1021.REOLINK.pak) as mentioned in [this forum](https://www.reddit.com/r/reolinkcam/comments/10iv3di/question_my_rlc510wa_cannot_connect_to_filezilla/) . ***Note*** firmware version 1.0.276 will not support ftps protocol, and the 'test' will fail

### Connect to wifi
1.  Provide wifi credentials of the 5GHz band SSID
2.  Provide the (local) `hostname` of the ftp box (not local ip address), port as 21, and the credentials for 'ipcameras' user. 
    1.  Using `hostname` 
        1.  makes it flexible to connect the linux box to the router either via wifi or RJ45. 
        2.  helps the cameras find and connect to the desktop ftp box, even if the router allocates a different ip address to it

### Provide FTPs details
1.  Enable the ftps soft switch
2.  Give the name of the remote location starting with `/`, but not ending with it. e.g. `/Clips`
3.  Save ftp details and test them for a successful connection

### Configure recording
1.  Remove watermark
2.  Select record schedules
3.  Enable audio recording
4.  Mark sensitivity, areas to avoid for false alarms etc. for persons and vehicles

### Secure
1.  Set a strong admin password


## Securing the router
1.  Avoid setting a common SSID for 2.4GHz and 5GHz so that devices can select them automatically. Devices may then pick the slower but stronger 2.4GHz band all the time instead of the less stronger but faster 5GHz band
2.  Hide the SSID to which IP Cameras connect
3.  Whitelist the 
    1.  Wifi mac address of each IP Camera
    2.  Wifi mac address of the desktop
    3.  Ethernet mac address of the desktop
    4.  Mac address of any other approved device to access the cameras and the desktop (e.g. phone)
4.  Scan 5GHz channels and select a less congested channel 
5.  If the ftp desktop box needs to be connected to the internet, the ip cameras can still be restrained by setting
    1.  appropriate *parental controls* in the router 
    2.  rules in the router firewall
    3.  Setting the gateway the same as the IP Address of the camera in the camera IP settings. Refer [this approach](https://medium.com/@ShinobiSystems/how-to-stop-a-reolink-cameras-or-others-from-sending-unauthorized-data-to-offsite-locations-47f6d1df3137) for more details
6. Connecting the ftp box to the router via RJ45
    1. Saves wifi bandwidth for the cameras
    2. Ensure that the router does not append any characters to the `hostname` when connecting via RJ45, and remove them

## Shutdown the ftp headless box remotely from within the same network

Refer [this](https://superuser.com/questions/703232/how-to-shut-down-a-networked-linux-pc)

`ssh <username on ftp box>@<host name of ftp box>` # *Connect to the ftp box from another linux PC on the same network, and authenticate with their password*

`sudo shutdown -h now` # *And authenticate with the password for the sudo user*


