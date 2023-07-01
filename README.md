# IP-Cameras
## Introduction / Purpose
1.   Leverage the **FTPs** capability offered by a few Security IP cameras, and upload motion video clips and photos to a local linux ftp server that has TLS enabled.
2.   Physically isolate the set-up from the internet unless otherwise desired.
3.   Save space on the ftp server by converting H.264 codec videos to H.265 codec as soon as they are uploaded. 

## Hardware
1.   Reolink - [RLC-510WA](https://reolink.com/us/product/rlc-510wa/)
2.   Desktop to run Ubuntu 22.04, with reasonable storage to store video clips and photos from multiple IP cameras
3.   Dualband wifi router with RJ45 and reasonable bandwidth to use the less congested 5GHz band 
4.   Display dummy (HDMI / DisplayPort) to use the linux box headless. This is an optional accessory for some PCs.

## Software
1.   Ubuntu 22.04 desktop
2.   vsftpd
3.   Filezilla
4.   Reolink [RLC-510WA firmware version 1.0.280 (1387_22100633)](https://support.reolink.com/attachments/token/1ISbkfiJ3uJ2rganejlK6JUvG/?name=IPC_523128M5MP.1387_22100633.RLC-510WA.OV05A10.5MP.WIFI1021.REOLINK.pak)

## On ubuntu desktop

### BIOS
Use relevant settings to automatically power on after a power failure

### Install vsftpd

Refer [How to install FTP server (VSFTPD) on Ubuntu](https://www.programbr.com/ubuntu/how-to-install-ftp-server-vsftpd-on-ubuntu/)

`sudo apt install nala` # *Use nala to install other software*

`sudo nala update`

`sudo nala install filezilla` # *Install filezilla*

`sudo nala install vsftpd` # *Install vsftpd*

`sudo service vsftpd status` # *Check if vsftpd service is active/running*

`vsftpd -v` # *Check the version of vsftpd*

`hostname` # *Get the hostname to provide in Filezilla for test and to provide in each IP Camera*


### Configure ufw

`sudo ufw status` # *Check the firewall's status. Could be inactive*

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

`echo "ipcamera" | sudo tee -a /etc/vsftpd.userlist` # *Add that user to the list of users who can use vsftpd*

`cat /etc/vsftpd.userlist` # *Check if the user is added to the list of users who can use vsftpd*

### Generate certificate
`sudo openssl req -x509 -nodes -days 7300 -newkey rsa:2048 -keyout /etc/ssl/private/vsftpd.pem -out /etc/ssl/private/vsftpd.pem` # *Generate a 2048-bit RSA key and self-signed SSL certificate that will be valid for 7300 days*


### Configure vsftpd
`sudo nano /etc/vsftpd.conf` # *Open the conf file*

Edit as needed for the following fields and values. Refer [Setting up vsftp](https://unix.stackexchange.com/questions/654625/setting-up-vsftp) , [Configuring the FTP Server](https://docs.openeuler.org/en/docs/20.09/docs/Administration/configuring-the-ftp-server.html)

```
#Edit the below
anonymous_enable=NO

# Uncomment the below
local_enable=YES
write_enable=YES
chroot_local_user=YES

## Add the below to the end
allow_writeable_chroot=YES
pasv_min_port=40000
pasv_max_port=50000

rsa_cert_file=/etc/ssl/private/vsftpd.pem
rsa_private_key_file=/etc/ssl/private/vsftpd.pem
ssl_enable=YES

userlist_enable=YES
userlist_file=/etc/vsftpd.userlist
userlist_deny=NO
```

**Optional**

`listen_ipv6=NO` # *May not use IPv6*


**Not sure**

`listen = YES` # *Refer [using standalone mode or not](https://www.ibiblio.org/pub/Linux/docs/linux-doc-project/linuxfocus/English/Archives/lf-2004_07-0341.pdf). Using standalone mode [allows the server to be accessible to clients connect via two network interfaces](https://serverfault.com/questions/454599/configure-ftp-server-with-two-different-ip-addresses-on-different-subnets-and-se), such as ethernet and wifi*

### Restart vsftpd
`sudo systemctl restart vsftpd` # *Restart vsftpd for changes to take effect*

## Test vsftpd

### Test using filezilla
1.  Test the ability to connect to the ftp server using
    1.   `hostname`
    2.   intranet ip address
2.  Test user credentials to log into the ftp server using
    1.   `ipcamera` user credentials for successful attempts
    2.   credentials of other users on the ftp box for unsuccessful attempts. i.e. vsftpd should block them
3.  Test if TLS is working from the certificate shown upon login as well as login messages)
4.  Test if directories are restricted. i.e. cannot traverse above home directory
5.  Test if downloading from ftp location to local location is working
6.  Test if upload / create new file are working on the ftp location

### Test headless operation
Boot the ftp box without a display / display dummy, keyboard and mouse connected to it. Connect to the ftp server from an ftp client on a different device. Some PCs may need a display dummy. 

### Tuneup SSH

Refer [A comprehensive guide to fixing slow SSH logins](https://jrs-s.net/2017/07/01/slow-ssh-logins/)

### Test ftp before any user ever logs into the ftp box
This simulates a power failure situation when vsftpd should start on its own. A headless operation test may also be good to confirm this. 

### Recode each video clip from H.264 codec to H.265 codec

This halves the space needed to store videos. Download the [vsftpd-log-listener.sh](vsftpd-log-listener.sh), that watches the vsftpd log for successful uploads, and then converts .mp4 files with H.264 codecs to .mpg files with H.265 codecs. It runs the conversion of each .mp4 files as a separate process. Each H.265 video will be stored in an external mount point under a directory structure that mirrors the source, and as a .mpg file. The external drive's mount point is passed as a argument in the service definition, using the [Environment directive](https://www.baeldung.com/linux/systemd-multiple-parameters). The original H.264 file (as .mp4) will be deleted after successful conversion.

`sudo chmod +x vsftpd-log-listener.sh` # *Permit executing the script*

`sudo mkdir /home/ipcamera/my-vsftpd` # *Create a directory to store the users shell scripts*

`sudo mv vsftpd-log-listener.sh /home/ipcamera/my-vsftpd/` # *Move the listener to the user's directory where shell scripts would be stored*

`sudo chown -R ipcamera:ipcamera /home/ipcamera/my-vsftpd` # *Change the ownership and group of the directory and all contents under it to the ipcamera user and group*

### Use an external drive to store H.265 video clips
This saves space on the internal drive by keeping only photos on it. It also helps redundancy in case the external drive is lost / stolen. Recoded H.265 video clips are maintained only on the external drive if the recoding is successful. i.e. if external drive is not connected / mounted, then the H.265 recoded videos will be stored on the internal drive.

1.  Mount the external drive automatically with appropriate entries in `/etc/fstab`. Provide the mount point as an ENVIRONMENT variable in the service declaration of the vsftpd-log-listener
2.  Ensure that `sudo` (not `ipcamera` user, as it is `sudo` who runs the service) has all permissions to write to the external drive mount point. Ensure [the ownwership, groups, and setgid](https://github.com/ln-komandur/linux-utils/blob/master/common-mountpoints.md) are set correctly.

### Run the vsftpd-log-listener as a service

Refer [How to Run Shell Script as Systemd in Linux](https://tecadmin.net/run-shell-script-as-systemd-service/) and [Redirect systemd service logs to file](https://unix.stackexchange.com/questions/321709/redirect-systemd-service-logs-to-file)

`sudo nano /lib/systemd/system/vsftpd-log-listener.service` # *Create a service for the listener*

Copy the following lines and save the file
```
[Unit]
Description=Watches vsftp log for successful uploads, and converts .mp4 files with H.264 codecs to .mpg files with H.265 codecs

[Service]
Environment = "EXT_DR_MNT_PT=/media/camera_clips" "BASE_FOLDER=/H_265_Clips" "KEEP_SOURCE=Y"
ExecStart=/home/ipcamera/my-vsftpd/vsftpd-log-listener.sh $EXT_DR_MNT_PT $BASE_FOLDER $KEEP_SOURCE
Restart=always
StandardOutput=append:/home/ipcamera/my-vsftpd/H264_to_H265_Codec_conversion_service.log
StandardError=append:/home/ipcamera/my-vsftpd/H264_to_H265_Codec_conversion_service_error.log

[Install]
WantedBy=default.target
```

`sudo systemctl daemon-reload` # *Reload the systemctl daemon to read the new file, and each time it after making any changes in .service file.*

`sudo systemctl enable vsftpd-log-listener.service` # *Enable the service to start on system boot*

`sudo systemctl start vsftpd-log-listener.service` # *Start the service now*

`sudo systemctl status vsftpd-log-listener.service` # *Verify the script is up and running as a systemd service.*

## On each IP Camera (RLC-510WA)

1.  Update firmware to version 1.0.280 so that the camera can use ftps (protocol) - this is available [here](https://support.reolink.com/attachments/token/1ISbkfiJ3uJ2rganejlK6JUvG/?name=IPC_523128M5MP.1387_22100633.RLC-510WA.OV05A10.5MP.WIFI1021.REOLINK.pak) per this [discussion about correct Reolink firmware version to support **FTPs**](https://www.reddit.com/r/reolinkcam/comments/10iv3di/question_my_rlc510wa_cannot_connect_to_filezilla/) .
***Note*** firmware version 1.0.276 will not support ftps protocol, and the 'test' will fail. 

### Connect to wifi
1.  Provide wifi credentials of the 5GHz band SSID
2.  Provide the (local) `hostname` of the ftp box (not local ip address), port as 21, and the credentials for `ipcamera` user. 
    1.  Using `hostname` 
        1.  makes it flexible to connect the linux box to the router either via wifi or RJ45. 
        2.  helps the cameras find and connect to the ftp box, even if the router allocates a different ip address to it

### Provide FTPs details

Refer [How to Set up FTP](https://support.reolink.com/hc/en-us/articles/900003742746-How-to-Set-up-FTP-via-Reolink-Client-New-Client-/)

1.  Enable the ftps soft switch
2.  Give the name of the remote location starting with `/`, but not ending with it. e.g. `/Clips` or `/Videos`
3.  [Change the *Transport Mode* from *Auto* to *Port*](https://www.reddit.com/r/reolinkcam/comments/10yq6yp/ftp_files_have_0kb/). Otherwise files uploaded to the ftp server (typically .mp4) may be just 0 Bytes.
4.  Save ftp details and test them for a successful connection. [Troubleshoot](https://support.reolink.com/hc/en-us/articles/360013262414-FTP-stops-working-/) as required, by reviewing and editing the `/etc/vsftpd.conf` file

### Configure recording
1.  Remove watermark
2.  Select record schedules
3.  Enable audio recording
4.  Mark sensitivity, areas to avoid for false alarms etc. for persons and vehicles

### Secure the cameras login
1.  Set a strong admin password


## Securing the router
1.  Check the signal strength of the 5GHz band in each of the camera locations
    1.  If it is strong enough (i.e. will not disconnect), then avoid setting a common SSID for 2.4GHz and 5GHz bands so that devices can select them automatically. Devices may then pick the slower but stronger 2.4GHz band all the time instead of the less stronger but faster 5GHz band
    2.  If it not strong enough (i.e. possibility of disconnections), then set a common SSID for 2.4GHz and 5GHz bands so that devices can select them automatically. Devices may then pick the slower but stronger 2.4GHz band but will not disconnect even if faster 5GHz band is not in range
2.  Hide the SSID to which IP Cameras connect
3.  Whitelist Wi-fi for the mac address of 
    1.  each IP Camera
    2.  the ftp box
    3.  any other approved device on the intranet to access the cameras and the ftp box (e.g. phone)
4.  Scan 5GHz channels and select a less congested channel 
5.  If the ftp box needs to be connected to the internet, the ip cameras can still be restrained by setting
    1.  appropriate *parental controls* in the router 
    2.  rules in the router firewall
    3.  Setting the gateway the same as the IP Address of the camera in the camera IP settings. Refer [this approach](https://medium.com/@ShinobiSystems/how-to-stop-a-reolink-cameras-or-others-from-sending-unauthorized-data-to-offsite-locations-47f6d1df3137) for more details
6. Connecting the ftp box to the router via RJ45
    1. Saves wifi bandwidth for the cameras
    2. Ensure that the router does not append any characters to the `hostname` when connecting via RJ45, and remove them

# Appendix

## Purge old files on the ftp box
-    Write a shell script that takes the mount point name(s), number of days of free space to clear for each of them, and file types to delete as arguments.
     - This script will find the oldest and newest files in **each** mout point and the space they consume. It will calculate the average daily space taken. If the free space on the mount point (drive) is less than the 'number of days of free space to clear', then it will delete files of the oldest day per the 'file types to delete' in the argument in **each** mount point. It will repeat 'calculate the average daily space taken, check and delete' until there is required free space is available for the number of days in **each** mount point. The average is calculated as a moving average.
-    Run this shell script as a nighly process. Service? that checks the time of the day?
     
## Shutdown the ftp headless box remotely from within the same network

Refer [this](https://superuser.com/questions/703232/how-to-shut-down-a-networked-linux-pc)

`ssh <sudo username on ftp box>@<host name of ftp box>` # *Connect to the ftp box from another linux PC on the same network, and authenticate with the sudo users credentials*

Use the following command trail which also shows typical responses

**su_user_on_ftp_box@ftp_box:~$** `shutdown -h now`
```
User ipcamera is logged in on sshd.
Please retry operation after closing inhibitors and logging out other users.
Alternatively, ignore inhibitors and users with 'systemctl poweroff -i'.
```
**su_user_on_ftp_box@ftp_box:~$** `systemctl poweroff -i`
```
==== AUTHENTICATING FOR org.freedesktop.login1.set-wall-message ===
Authentication is required to set a wall message
Authenticating as: su_user_on_ftp_box,,, (su_user_on_ftp_box)
Password: 
==== AUTHENTICATION COMPLETE ===
==== AUTHENTICATING FOR org.freedesktop.login1.power-off-multiple-sessions ===
Authentication is required to power off the system while other users are logged in.
Authenticating as: su_user_on_ftp_box,,, (su_user_on_ftp_box)
Password: 
==== AUTHENTICATION COMPLETE ===
su_user_on_ftp_box@ftp_box:~$ Connection to ftp_box closed by remote host.
Connection to ftp_box closed.
```

## Useful learning resources found on the path to solutioning

Refer [this for the command to convert videos one at a time](https://stackoverflow.com/questions/58742765/convert-videos-from-264-to-265-hevc-with-ffmpeg)

Refer [this to find all MP4 files within subdirectory to compress using ffmpeg](https://stackoverflow.com/questions/56717674/code-must-find-all-mp4-files-within-subdirectory-to-compress-using-ffmpeg)

Refer [this to do a batch conversion but in the reverse direction](https://askubuntu.com/questions/707397/batch-convert-h-265-mkv-to-h-264-with-ffmpeg-to-make-files-compatible-for-re-enc). This covers `.ts` file extensions
