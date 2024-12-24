#!/bin/bash

datetime=$(date +%Y_%m_%d_%H_%M_%S)

log_file="local_build_${datetime}.log"
# Export all output to log_file
exec > >(tee -a "$log_file") 2>&1

function message() {
    type=$1
    string=$2

    case $type in
        1)
        # Info
        echo "[INFO] $string"
        ;;
        2)
        # Warning
        echo "[WARN] $string"
        ;;
        3)
        # Error
        echo "[ERROR] $string"
        exit 1
        ;;
    esac
}

## Create local requirements for hosting pi2.com content
## Steps
# Install required packages
# Check if pi2.com is reachable
# Test ssh connection to apache on pi2.com
# Check /expansion/backups/daily/$day exists
# 

## Run update and upgrades without prompt
message 1 "Running apt-get  update and upgrade"
apt-get update && apt-get upgrade -y

## Install required packages without prompt if they don't exist, update if they do
packages=(bash wget curl net-tools inotify-tools apache2 zip unzip gzip imagemagick virt-what) 

for package in "${packages[@]}"; do
        message 1 "Installing $package"
        apt-get install -y "$package"
done

# Run virt-what and determine installation type, if hyper-v install linux-azure, if vmware install open-vm-tools
virt=$(virt-what)

if [ "$virt" == "vmware" ]; then
        message 1 "This VM is running on VMware"
        message 1 "Installing open-vm-tools"
        apt-get install -y open-vm-tools 
        message 1 "Mountpoint is /mnt/hgfs/shared"
        mountpoint=/mnt/hgfs/shared
elif [ "$virt" == "hyperv" ]; then
        message 1 "This VM is running on Hyper-V"
        message 1 "Installing linux-azure and cifs-utils"
        apt-get install -y linux-azure cifs-utils
        message 1 "Mountpoint is /mnt/shared"
        mountpoint=/mnt/shared
else
        message 3 "Unsupported hypervisor '$virt'"
        exit 1
fi

# Create the file /usr/bin/root which contains 'sudo bash'
message 1 "Creating /usr/bin/root"
echo 'sudo bash' | sudo tee /usr/bin/root > /dev/null
sudo chmod +x /usr/bin/root

# Create the file /usr/bin/apache which contains 'sudo su - apache'
message 1 "Creating /usr/bin/apache"
echo 'sudo su - apache' | sudo tee /usr/bin/apache > /dev/null
sudo chmod +x /usr/bin/apache

# Create the file /usr/bin/kevin which contains 'sudo su - kevin'
message 1 "Creating /usr/bin/kevin"
echo 'su - kevin' | sudo tee /usr/bin/kevin > /dev/null
sudo chmod +x /usr/bin/kevin

# Check if fstab contains the shared folder
message 1 "Checking if shared folder is in fstab"
if grep -q "/mnt/shared" /etc/fstab; then
        message 1 "Shared folder already in fstab"
else
        message 1 "Shared folder not in fstab, adding"
        # Edit fstab to include "#SMB Mount for Expansion \n //192.168.0.4/Expansion /mnt/shared cifs credentials=/etc/smbcredentials,vers=3.0,iocharset=utf8,file_mode=0777,dir_mode=0777 0 0"
        echo -e "#SMB Mount for Expansion \n//192.168.0.4/Expansion /mnt/shared cifs credentials=/etc/smbcredentials,vers=3.0,iocharset=utf8,file_mode=0777,dir_mode=0777 0 0" | sudo tee -a /etc/fstab > /dev/null
        message 1 "Reloading systemd daemon"
        systemctl daemon-reload
fi

# Add /etc/smbcredentials
username=Kevin
password=Daisy12345
if [ ! -f "/etc/smbcredentials" ]; then
        message 1 "Creating /etc/smbcredentials"
        echo -e "username=$username\npassword=$password" | sudo tee /etc/smbcredentials > /dev/null
        sudo chmod 600 /etc/smbcredentials
else
        message 1 "/etc/smbcredentials already exists"
fi

# Mount all in fstab
message 1 "Mounting all in fstab"
mount -a

# Check if /mnt/hgfs/shared exists
if [ ! -d "/mnt/hgfs/shared" ]; then
        message 3 "Shared folder /mnt/hgfs/shared does not exist"
        exit 1
fi

