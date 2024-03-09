#!/bin/bash

# Vars
timestamp="$(date "+%Y_%m_%d-%H_%M_%S")"
mkdir -p logs_mount

{
# Functions
function checkMount(){
    if [ -d /mnt/hgfs/shared ]; then
        # Mount is present
        return 0
    else
        return 1
    fi
}

function message(){
    case $1 in
    0) echo "[INFO] $2";;
    1) echo "[ERROR] $2";;
    2) echo "[WARNING] $2";;
    *) echo "[BAD-USAGE] $1 | $2"
    esac
}

# Install packages
message 0 "Running apt-get update/upgrade"
sudo apt-get update -y
sudo apt-get upgrade -y


packages="apache2 open-vm-tools net-tools wget curl vim imagemagick bash sudo gzip zip unzip"

for install_package in ${packages[@]}; do
    message 0 "Installing $install_package"
    apt-get install -qq -y $install_package
done

# Force stopping apache
/usr/sbin/apachectl stop &>/dev/null
runuser -l apache -- -c '/usr/sbin/apachectl start'  &>/dev/null

# Configure apache
mkdir -p /home/apache
useradd apache
usermod -g users apache
chown -R apache:users /home/apache
chmod 700 /home/apache

if checkMount; then
    message 0 "Mount found"
else
    message 2 "Mount check failed, running mount fix script"
    cp /etc/fstab /etc/fstab.${timestamp}.bak
    echo -e "\n# VMWare Mount Fix\nvmhgfs-fuse /mnt/hgfs  fuse defaults,auto,allow_other,_netdev   0   0\n" >> /etc/fstab
    message 0 "Reloading daemon"
    systemctl daemon-reload
    message 0 "Running mount -a"
    mount -a
    if checkMount; then
    message 0 "Mount fixed"
    else
        message 1 "Unable to fix mount, see above errors"
        exit 1
    fi
fi

# Get latest dir for cgi
latest_cgi=$(ls -t /mnt/hgfs/shared/cgi | head -1)
if [ -z "$latest_cgi" ]; then
message 1 "latest_cgi is empty"
exit 1
fi



# Apache changes
message 0 "Stopping apache2"
systemctl stop apache2
message 0 "Disabling autostart for apache2"
systemctl disable apache2

# Unzip targets
unzip_targets=(apps web)

for unzip_target_entry in ${unzip_targets[@]}; do
    if [ -d /${unzip_target_entry}.bak ]; then
        message 2 "Removing old backup for ${unzip_target_entry}"
        if ! rm -rf /${unzip_target_entry}.bak; then
            echo "Failed to remove '/${unzip_target_entry}.bak'"
        fi
    fi
    if [ -d /${unzip_target_entry} ]; then
        message 0 "/${unzip_target_entry} already exists, moving it to /${unzip_target_entry}.bak"
        if ! mv -f /${unzip_target_entry} /${unzip_target_entry}.bak; then
            message 2 "Failed to move /${unzip_target_entry} to /${unzip_target_entry}.bak!"
        fi
    fi

    if [ -f /mnt/hgfs/shared/cgi/$latest_cgi/${unzip_target_entry}.zip ]; then
        message 0 "Unzipping ${unzip_target_entry}"
        unzip -o -d / /mnt/hgfs/shared/cgi/$latest_cgi/${unzip_target_entry}.zip 1>/dev/null
        else
        message 2 "No '/mnt/hgfs/shared/cgi/$latest_cgi/${unzip_target_entry}.zip' found!"
    fi
done

# etc apache
if [ -d /etc/apache2 ]; then
    message 0 "/etc/apache2 already exists, moving it to /etc/apache2.bak"
    if [ -d /etc/apache2.bak ]; then
    message 2 "/etc/apache2.bak already exists, removing it"
    rm -rf /etc/apache2.bak
    fi
    if ! mv -f /etc/apache2 /etc/apache2.bak; then
        message 2 "Failed to move /etc/apache2 to /etc/apache2.bak!"
    fi
fi

if [ -f /mnt/hgfs/shared/cgi/$latest_cgi/etcapache.zip ]; then
    message 0 "Unzipping etcapache"
    unzip -o -d / /mnt/hgfs/shared/cgi/$latest_cgi/etcapache.zip 1>/dev/null
else
    message 2 "No '/mnt/hgfs/shared/cgi/$latest_cgi/${unzip_target_entry}.zip' found!"
fi

# Fix for cgi
if [ -d /usr/lib/cgi-bin ]; then
    message 0 "cgi-bin lib exists, replacing it and creating symlink"
    mv /usr/lib/cgi-bin /usr/lib/cgi-bin.old 
fi
ln -s /apps/html/cgi /usr/lib/cgi-bin

# Ownership fixes
message 0 "Ownership fixes"
mkdir -p /logs/html/gallery
chown -R apache:users /apps /logs /web /etc/apache2

# Start apache
message 0 "Starting apache as user apache"
runuser -l apache -- -c '/usr/sbin/apachectl start'


# Final message
echo -e "\n========== Apache should be available on\n$(hostname -I | awk '{print $1}'):1092\n=========="

} | tee -a logs_mount/"log_mount_${timestamp}.log"
