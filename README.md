# IP-Cameras

Connect Wifi IP Cameras to a dedicated Wifi router and upload photos and videos from them to an local ftp server.
## Hardware
1.   Reolink - RLC-510WA
2.   Desktop that can run Ubuntu 22.04, with reasonable storage to store video clips and photos

## Software
1.   Ubuntu 22.04 desktop
2.   vsftpd
3.   Filezilla
4.   Reolink RLC-510WA firmware version 1.0.280 (1387_22100633)


## References

1.   https://www.programbr.com/ubuntu/how-to-install-ftp-server-vsftpd-on-ubuntu/
2.   https://unix.stackexchange.com/questions/654625/setting-up-vsftp
3.   https://www.reddit.com/r/reolinkcam/comments/10iv3di/question_my_rlc510wa_cannot_connect_to_filezilla/ 

## On ubuntu desktop

### Install vsftpd

`sudo apt install nala`

`sudo nala update`

`sudo nala install filezilla`

`sudo nala install vsftpd`

`sudo service vsftpd status`

`sudo nano /etc/vsftpd.conf`

`hostname`

`vsftpd -v`


### Configure ufw

`sudo ufw status` 

`sudo ufw allow 20/tcp`

`sudo ufw allow 21/tcp`

`sudo ufw allow 40000:50000/tcp`

`sudo ufw allow 990/tcp`

`sudo ufw allow OpenSSH`

`sudo nala install ssh`

`sudo ufw allow OpenSSH`

`sudo ufw disable`

`sudo ufw enable`

`sudo ufw status`


### ftp user id
`sudo adduser ipcamera`

`echo "cameras" | sudo tee -a /etc/vsftpd.userlist`

`cat /etc/vsftpd.userlist`

### Generate certificate
`sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/vsftpd.pem -out /etc/ssl/private/vsftpd.pem`


### Configure vsftpd
`sudo nano /etc/vsftpd.conf`
  
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

**Optional
```
listen_ipv6=NO #(we may do not use IPv6)
```

**Not sure
```
listen = YES
```

`sudo systemctl restart vsftpd`


### Test with filezilla
1.  Test using hostname
2.  Test using intranet ip address
3.  Test if TLS is working (from the certificate shown as well as messages)
4.  Test if directories are resrticted
5.  Test if downloading from ftp location to local location is working

## On each IP Camera

1.  Update firmware to version 1.0.280 to use ftps (protocol)
2.  Provide the (local) hostname of the ftp box (not local ip address)
3.  Provide wifi credentials
4.  Select record schedules
5.  Mark sensitivity, areas to avoid for false alarms etc.



