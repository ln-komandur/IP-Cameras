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

echo Installing nala
apt install nala # Use nala to install other software

echo Updating nala
nala update

echo Installing filezilla
nala install filezilla # Install filezilla

echo Installing ssh
nala install ssh # Install ssh if not already installed

echo Installing vsftpd
nala install vsftpd # Install vsftpd

echo vsftpd status is
service vsftpd status # Check if vsftpd service is active/running

echo vsftpd version is
vsftpd -v # Check the version of vsftpd

echo Host name is $HOSTNAME # Get the hostname to provide in Filezilla for test and to provide in each IP Camera

echo Configuring UFW

ufw status # Check the firewall's status. Could be inactive

ufw allow 20/tcp # Open port 20 (FTP data port)

ufw allow 21/tcp # Open port 21 (FTP command port)

ufw allow 40000:50000/tcp # Open ports 40000-50000 for the range of passive FTP

ufw allow 990/tcp # Open port 990 for TLS

ufw allow OpenSSH # Allow OpenSSH

ufw disable && ufw enable # Disable and enable UFW

ufw status # Check if UFW is active

echo Adding ftp user id

adduser $1 # Add a user just to ftp photos and video clips from ip cameras

echo $1 | tee -a /etc/vsftpd.userlist # Add that user to the list of users who can use vsftpd

cat /etc/vsftpd.userlist # Check if the user is added to the list of users who can use vsftpd

echo Generating TLS certificate

openssl req -x509 -nodes -days 7300 -newkey rsa:2048 -keyout /etc/ssl/private/vsftpd.pem -out /etc/ssl/private/vsftpd.pem # Generate a 2048-bit RSA key and self-signed SSL certificate that will be valid for 7300 days

echo Configuring vsftpd

echo anonymous_enable=NO
sed -i 's/anonymous_enable=NO/anonymous_enable=NO/g' /etc/vsftpd.conf

echo local_enable=YES
sed -i 's/local_enable=NO/local_enable=YES/g' /etc/vsftpd.conf

echo write_enable=YES
sed -i 's/write_enable=NO/write_enable=YES/g' /etc/vsftpd.conf

echo chroot_local_user=YES
sed -i 's/chroot_local_user=NO/chroot_local_user=YES/g' /etc/vsftpd.conf

echo allow_writeable_chroot=YES
sed -i 's/allow_writeable_chroot=NO/allow_writeable_chroot=YES/g' /etc/vsftpd.conf


echo '
pasv_min_port=40000
pasv_max_port=50000

rsa_cert_file=/etc/ssl/private/vsftpd.pem
rsa_private_key_file=/etc/ssl/private/vsftpd.pem
ssl_enable=YES

userlist_enable=YES
userlist_file=/etc/vsftpd.userlist
userlist_deny=NO
' | sudo tee /etc/vsftpd.conf
