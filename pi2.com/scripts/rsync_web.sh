#!/bin/bash

# Define variables
SOURCE_HOST="192.168.0.100"
SOURCE_DIR="/web/gallery2/catagories/new/"
LOCAL_DIR="/web/gallery2/catagories/new/"

# Function to display usage
usage() {
    echo "Usage: $0 [-h source_host]"
    echo "  -h: Source host IP address/hostname (default: 192.168.0.100)"
    exit 1
}

# Parse command line options
while getopts "h:" opt; do
    case $opt in
        h)
            SOURCE_HOST="$OPTARG"
            ;;
        \?)
            usage
            ;;
    esac
done

# Ensure trailing slash for directories
SOURCE_DIR="${SOURCE_DIR%/}/"
LOCAL_DIR="${LOCAL_DIR%/}/"

# Run rsync
# Options explained:
# -a: archive mode (preserves permissions, timestamps, etc.)
# -v: verbose output
# -z: compress during transfer
# --progress: show progress during transfer
# --update: skip files that are newer on the receiver
rsync -avz --progress --update "${SOURCE_HOST}:${SOURCE_DIR}" "${LOCAL_DIR}"

# Check rsync exit status
if [ $? -eq 0 ]; then
    echo "Synchronization completed successfully"
else
    echo "Error: Synchronization failed"
    exit 1
fi

exit 0