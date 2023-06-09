#!/bin/bash
#ref: https://unix.stackexchange.com/questions/28791/prompt-for-sudo-password-and-programmatically-elevate-privilege-in-bash-script
#ref: https://askubuntu.com/a/30157/8698

if (($EUID != 0)); then
  if [[ -t 1 ]]; then
#https://unix.stackexchange.com/questions/218715/what-does-t-1-do
    sudo "$0" "$@"
  else
    exec 1>output_file
    gksu "$0 $@"
  fi
  exit
fi
echo "This script installs filezilla, ssh, vsftpd, configures it as well as UFW."
echo
echo


if [ $# -eq 0 ]
then
    echo "Give the name of the user id to use on the ftp server. Exiting"
    exit 1
fi

echo @-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@
echo Add a user just to ftp photos and video clips from ip cameras
echo @-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@
adduser $1 # Add a user just to ftp photos and video clips from ip cameras

echo @-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@
echo Installing nala
echo @-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@
apt install nala # Use nala to install other software

echo @-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@
echo Updating nala
echo @-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@
nala update

echo @-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@
echo Installing filezilla
echo @-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@
nala install filezilla # Install filezilla

echo @-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@
echo Installing ssh
echo @-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@
nala install ssh # Install ssh if not already installed

echo @-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@
echo Installing ffmpeg
echo @-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@
nala install ffmpeg # Install ffmpeg if not already installed

echo @-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@
echo Installing VLC
echo @-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@
nala install vlc # Install vlc if not already installed

echo @-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@
echo Installing vsftpd
echo @-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@
nala install vsftpd # Install vsftpd

echo @-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@
echo vsftpd status is
echo @-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@
service vsftpd status # Check if vsftpd service is active/running

echo @-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@
echo vsftpd version is
vsftpd -v # Check the version of vsftpd
echo @-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@
echo Host name is $HOSTNAME # Get the hostname to provide in Filezilla for test and to provide in each IP Camera

echo @-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@
echo Add the provided user to the list of users who can use vsftpd 
echo @-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@
echo $1 | tee -a /etc/vsftpd.userlist # Add that user to the list of users who can use vsftpd
cat /etc/vsftpd.userlist # Check if the user is added to the list of users who can use vsftpd

echo @-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@
echo Generating TLS certificate
echo @-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@
openssl req -x509 -nodes -days 7300 -newkey rsa:2048 -keyout /etc/ssl/private/vsftpd.pem -out /etc/ssl/private/vsftpd.pem # Generate a 2048-bit RSA key and self-signed SSL certificate that will be valid for 7300 days

echo @-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@
echo Backing up the original vsftpd.conf
echo @-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@
cp /etc/vsftpd.conf /etc/vsftpd-original.conf

echo @-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@
echo Configuring vsftpd
echo @-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@


echo @-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@
echo #Edit anonymous_enable=NO
echo @-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@
sed -i 's/anonymous_enable=YES/anonymous_enable=NO/g' /etc/vsftpd.conf

echo @-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@
echo Uncomment local_enable=YES
echo @-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@
sed -i 's/#local_enable=YES/local_enable=YES/g' /etc/vsftpd.conf

echo @-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@
echo Uncomment write_enable=YES
echo @-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@
sed -i 's/#write_enable=YES/write_enable=YES/g' /etc/vsftpd.conf

echo @-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@
echo Uncomment chroot_local_user=YES. This occurs in 2 places in the conf file
echo @-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@
sed -i 's/#chroot_local_user=YES/chroot_local_user=YES/g' /etc/vsftpd.conf


echo @-@-@-@-@-@-@-@-@-@-@ ADDING MANY OTHER PARAMETERS @-@-@-@-@-@-@-@-@-@-@
echo '
## Added the below to the end of vsftpd.conf
allow_writeable_chroot=YES
pasv_min_port=40000
pasv_max_port=50000

rsa_cert_file=/etc/ssl/private/vsftpd.pem
rsa_private_key_file=/etc/ssl/private/vsftpd.pem
ssl_enable=YES

userlist_enable=YES
userlist_file=/etc/vsftpd.userlist
userlist_deny=NO
' | sudo tee -a /etc/vsftpd.conf

echo @-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@
echo Restart vsftpd service
echo @-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@
service vsftpd restart # Restart vsftpd service



echo @-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@
echo Configuring UFW
echo @-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@-@

ufw status # Check the firewall's status. Could be inactive

ufw allow 20/tcp # Open port 20 (FTP data port)

ufw allow 21/tcp # Open port 21 (FTP command port)

ufw allow 40000:50000/tcp # Open ports 40000-50000 for the range of passive FTP

ufw allow 990/tcp # Open port 990 for TLS

ufw allow OpenSSH # Allow OpenSSH

ufw disable && ufw enable # Disable and enable UFW

ufw status # Check if UFW is active
