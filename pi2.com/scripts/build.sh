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
packages=(bash wget curl net-tools inotify-tools apache2 zip gzip tar unzip gzip imagemagick virt-what psmisc less) 

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

mkdir -p $mountpoint

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

if [ ! -f "/etc/smbcredentials" ]; then
        username=Kevin
        password=Daisy12345
        message 1 "Creating /etc/smbcredentials"
        echo -e "username=$username\npassword=$password" | sudo tee /etc/smbcredentials > /dev/null
        sudo chmod 600 /etc/smbcredentials
else
        message 1 "/etc/smbcredentials already exists"
fi

# Mount all in fstab
message 1 "Mounting all in fstab"
mount -a

# Check /mnt/shared exists
message 1 "Checking if /mnt/shared exists"
if [ -d "/mnt/shared" ]; then
        message 1 "/mnt/shared exists"
else
        message 3 "/mnt/shared does not exist"
        exit 1
fi

# Get latest shared folder date
latest=$(ls -t /mnt/shared/backups/daily/ | head -n1 | head -n1)
message 1 "Latest shared folder is $latest"

# Check apps.zip exists in latest shared folder
message 1 "Checking if apps.zip exists in $latest"
if [ -f "/mnt/shared/backups/daily/$latest/apps.zip" ]; then
        message 1 "apps.zip exists in $latest"
else
        message 3 "apps.zip does not exist in $latest"
        exit 1
fi

# Move /apps and /web to today's date
message 1 "Moving /apps and /web to $(date +%Y_%m_%d)"
mv /apps /apps_$(date +%Y_%m_%d)
mv /web /web_$(date +%Y_%m_%d)

# Move /etc/apache2 to /etc/apache2_$(date +%Y_%m_%d)
message 1 "Moving /etc/apache2 to /etc/apache2_$(date +%Y_%m_%d)"
mv /etc/apache2 /etc/apache2_$(date +%Y_%m_%d)

# Unzip apps.zip and web.zip to /apps and /web
message 1 "Unzipping apps.zip and web.zip to /apps and /web"
unzip /mnt/shared/backups/daily/$latest/apps.zip -d /
unzip /mnt/shared/backups/daily/$latest/web.zip -d /

# Unzip etcapache.zip to /
message 1 "Unzipping etcapache.zip to /"
unzip /mnt/shared/backups/daily/$latest/etcapache.zip -d /

# Remove /usr/lib/cgi-bin and repoint to /apps/html/cgi
message 1 "Removing /usr/lib/cgi-bin and repointing to /apps/html/cgi"
rm -rf /usr/lib/cgi-bin
ln -s /apps/html/cgi /usr/lib/cgi-bin

# Create the user apache if it doesn't already exist
message 1 "Creating user apache"
if id apache &>/dev/null; then
        message 1 "User apache already exists"
else
        message 1 "User apache does not exist, creating"
        # Create /home/apache if it doesn't exist
        if [ ! -d "/home/apache" ]; then
                message 1 "Creating /home/apache"
                mkdir /home/apache
        fi

        # Copy /etc/skel/.bashrc and /etc/skel/.profile to /home/apache
        message 1 "Copying /etc/skel/.bashrc and /etc/skel/.profile to /home/apache"
        cp /etc/skel/.bashrc /home/apache
        cp /etc/skel/.profile /home/apache

        # Create user apache, set home directory to /home/apache, login shell to /bin/bash
        message 1 "Creating user apache"
        useradd -d /home/apache -s /bin/bash apache

        # Set group of apache to users
        message 1 "Setting group of apache to users"
        usermod -g users apache
        usermod -aG apache apache

        # Set password for apache
        message 1 "Setting password for apache"
        echo "apache:apache" | chpasswd
fi


# Update ownership of /apps, /web, /logs and /etc/apache2 to apache
message 1 "Updating ownership of /apps, /web, /logs and /etc/apache2 to apache"
chown -R apache:users /apps /web /logs /etc/apache2

# Restart apache
message 1 "Restarting apache"
systemctl restart apache2

# Check if localhost/cgi/gallery/mini is reachable
message 1 "Checking if localhost/cgi/gallery/mini is reachable"
if curl -s "http://localhost/cgi/gallery/mini/" | grep -q "clean_generated_files"; then
        message 1 "http://localhost/cgi/gallery/mini/ is reachable"
else
        message 3 "http://localhost/cgi/gallery/mini/ is not reachable"
        exit 1
fi

