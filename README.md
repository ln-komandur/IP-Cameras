# IP-Cameras
## Introduction
This project leverages the FTPs capability offered by a few Security IP cameras, and uploads motion video clips and photos on a local linux ftp server. The set-up is physically isolated from the internet unless otherwise desired.

## Hardware
1.   Reolink - RLC-510WA
2.   Desktop to run Ubuntu 22.04, with reasonable storage to store video clips and photos from multiple IP cameras
3.   Dualband wifi router with RJ45 and reasonable bandwidth to use the less congested 5G band 
4.   Display dummy (HDMI / DisplayPort) to use the linux box headless

## Software
1.   Ubuntu 22.04 desktop
2.   vsftpd
3.   Filezilla
4.   Reolink RLC-510WA firmware version 1.0.280 (1387_22100633)


## References

1.   https://www.programbr.com/ubuntu/how-to-install-ftp-server-vsftpd-on-ubuntu/
2.   https://unix.stackexchange.com/questions/654625/setting-up-vsftp
3.   https://www.reddit.com/r/reolinkcam/comments/10iv3di/question_my_rlc510wa_cannot_connect_to_filezilla/ - has the link to the correct firmware version

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

`sudo ufw disable && sudo ufw enable` # *#Disable and enable UFW*

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
```
listen_ipv6=NO #(may not use IPv6)
```

**Not sure**
```
listen = YES
```

`sudo systemctl restart vsftpd`


### Testing with filezilla
1.  Test using `hostname` to connect
2.  Test using intranet ip address
3.  Test using 'ipcamera' user credentials to see if connections are successful
4.  Test using other user credentials to see if connections are unsuccessful
5.  Test if TLS is working (from the certificate shown as well as login messages)
6.  Test if directories are resrticted. i.e. cannot traverse above home directory
7.  Test if downloading from ftp location to local location is working

### Testing ftp with display dummy
Headless operation mode

### Testing ftp without any user logging into the desktop
This simulates a power failure situation

### Batch job to recode each video clip from H.264 to H.265
TBD - using ffmpeg commands in a shell script and executing them on schedule as a cronjob

### Use an external drive to store H.265 video clips
This is to save space on the internal drive
1.  Keep photos on local drive as well as external drive (i.e. in case the external drive is lost / stolen)
2.  Keep only H.265 video clips on external drive
3.  Do not keep any video clips on local drive after the recoding is successful (keep only if external drive is not connected) 

## Connecting each IP Camera

1.  Update firmware to version 1.0.280 so that the camera can use ftps (protocol) - this is available [here](https://support.reolink.com/attachments/token/1ISbkfiJ3uJ2rganejlK6JUvG/?name=IPC_523128M5MP.1387_22100633.RLC-510WA.OV05A10.5MP.WIFI1021.REOLINK.pak) as mentioned in [this forum](https://www.reddit.com/r/reolinkcam/comments/10iv3di/question_my_rlc510wa_cannot_connect_to_filezilla/) . ***Note*** firmware version 1.0.276 will not support ftps protocol, and the 'test' will fail
2.  Provide wifi credentials of the 5G band SSID
3.  Provide the (local) `hostname` of the ftp box (not local ip address), port as 21, and the credentials for 'ipcameras' user. Using `hostname` makes it flexible to connect the linux box to the router either via wifi or RJ45. The latter will save wifi bandwidth for the cameras
4.  Enable the ftps soft switch
5.  Give the name of the remote location starting with `/`, but not ending with it. e.g. `/Clips`
6.  Save ftp details and test them for a successful connection
7.  Select record schedules
8.  Mark sensitivity, areas to avoid for false alarms etc. for persons and vehicles

## Securing the router

1.  Hide the SSID to which IP Cameras connect
2.  Whitelist the 
    1.  Wifi mac address of each IP Camera
    2.  Wifi mac address of the desktop
    3.  Ethernet mac address of the desktop
    4.  Mac address of any other approved device to access the cameras and the desktop (e.g. phone)



