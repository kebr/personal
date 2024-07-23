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
packages=(bash wget curl net-tools inotify-tools apache2 zip unzip gzip imagemagick)

for package in "${packages[@]}"; do
        apt install -y "$package"
done

## Run ps1 prep script
#powershell.exe -File test.ps1

## Check if pi2.com resolves to 192.168.0.40
if [[ $(getent hosts pi2.com | awk '{print $1}') == "192.168.0.40" ]]; then
    message 1 "pi2.com resolves to 192.168.0.40 - using rsync mode"
    # Test ssh connection to apache on pi2.com
    if ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null pi2.com 'exit 0'; then
        message 1"SSH connection to pi2.com successful"
    else
        message 3 "SSH connection to pi2.com failed"
    fi

    # Rsync pi2.com content - /apps /logs and /web - keep owner and timestamps on files/folders
    rsync -av --chown=: --preserve=mode,timestamps --include='/apps' --include='/logs' --include='/web' --include='*/' --exclude='*' apache@pi2.com:/ /    

else
    message 2 "pi2.com does not resolve to 192.168.0.40 - using copy mode"
fi
