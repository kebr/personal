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
apt update && apt upgrade -y

## Install required packages without prompt if they don't exist, update if they do
packages=(bash wget curl net-tools inotify-tools apache2 zip unzip gzip imagemagick cifs-utils virt-what) 

for package in "${packages[@]}"; do
        apt install -y "$package"
done

# Run virt-what and determine installation type, if hyper-v install linux-azure, if vmware install open-vm-tools
virt=$(virt-what)

if [ "$virt" == "vmware" ]; then
        apt install -y open-vm-tools 
        mountpoint=/mnt/hgfs/shared
elif [ "$virt" == "hyperv" ]; then
        apt install -y linux-azure cifs-utils
        mountpoint=/mnt/shared
else
        message 3 "Unsupported hypervisor '$virt'"
        exit 1
fi

# Check if /mnt/hgfs/shared exists
if [ ! -d "/mnt/hgfs/shared" ]; then
        message 3 "Shared folder /mnt/hgfs/shared does not exist"
        exit 1
fi

# Create the file /usr/bin/root which contains 'sudo bash'
echo 'sudo bash' | sudo tee /usr/bin/root > /dev/null
sudo chmod +x /usr/bin/root

# Create the file /usr/bin/apache which contains 'sudo su - apache'
echo 'sudo su - apache' | sudo tee /usr/bin/apache > /dev/null
sudo chmod +x /usr/bin/apache

# Create the file /usr/bin/kevin which contains 'sudo su - kevin'
echo 'su - kevin' | sudo tee /usr/bin/kevin > /dev/null
sudo chmod +x /usr/bin/kevin

# Check if fstab contains the shared folder
if grep -q "/mnt/shared" /etc/fstab; then
        message 1 "Shared folder already in fstab"
else
        message 1 "Shared folder not in fstab, adding"
        # Edit fstab to include "#SMB Mount for Expansion \n //192.168.0.4/Expansion /mnt/shared cifs credentials=/etc/smbcredentials,vers=3.0,iocharset=utf8,file_mode=0777,dir_mode=0777 0 0"
        echo -e "#SMB Mount for Expansion \n //192.168.0.4/Expansion /mnt/shared cifs credentials=/etc/smbcredentials,vers=3.0,iocharset=utf8,file_mode=0777,dir_mode=0777 0 0" | sudo tee -a /etc/fstab > /dev/null
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


