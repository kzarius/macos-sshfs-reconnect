#!/usr/bin/env bash

# Grabs vars from an .env file in this dir:
# MOUNT_SOURCE: The source path on the remote server.
# MOUNT_TARGET: The target path on the local machine.
# MOUNT_NAME: The name of the mounted volume.
# SSH_PROFILE: The SSH profile to use for the connection.

script_path="/Users/kaeomc/Documents/Code/macos-sshfs-reconnect"

# Import the .env file:
source "${script_path}/$1"

# Log file:
log_file="${script_path}/reconnect.log"

echo "Running the SSHFS reconnect script." >> $log_file



# Check if the target directory is empty:
checkIfDirEmpty() {
    if [ -d "${MOUNT_TARGET}" ] && [[ "$(ls -A ${MOUNT_TARGET})" ]]; then
        # The mount target is not empty.
        return 0
    else
        # The mount target is empty.
        return 1
    fi
}

# Check to see if the source is already mounted:
checkIfMounted() {
    # Use df to check if the source is already mounted:
    is_mounted=$(df -h | grep -c "${MOUNT_SOURCE}")

    # If the source is already mounted, return 1:
    if [[ $is_mounted == 1 ]]; then
        return 1
    fi

    # Otherwise, return 0:
    return 0
}

# Function to attempt to mount the source:
attemptToMount() {
    sshfs "${SSH_PROFILE}":"${MOUNT_SOURCE}" "${MOUNT_TARGET}" -ovolname="${MOUNT_NAME}" -o kill_on_unmount,reconnect,allow_other,defer_permissions,direct_io,ServerAliveInterval=15
    
    if [[ $? == 0 ]]; then
        # Successfully mounted the source.
        return 1
    else
        # Failed to mount the source.
        return 0
    fi
}



# Check if the source is already mounted and exit if it is:
checkIfMounted
if [[ $? == 1 ]]; then

    # Check if the target directory is empty.
    # If it is empty, then we're most likely looking at a stale mount.
    checkIfDirEmpty
    if [[ $? == 0 ]]; then
        # It's not empty, so we're going to assume the mount is still valid.
        exit 0
    fi
fi

# Attempt to mount the source:
attemptToMount
if [[ $? == 0 ]]; then
    # Forcing the mount target to unmount:
    if (diskutil unmount force "${MOUNT_TARGET}" | grep -c "Unmount successful"); then

        # Successfully unmounted the mount target. Attempting to mount the source again:
        attemptToMount
        if [[ $? == 1 ]]; then
            # Succeeded so we can exit.
            exit 0
        fi

    fi
fi

# Check if the source is now mounted:
checkIfMounted
if [[ $? == 1 ]]; then
    exit 0
fi

echo "Failed to mount ${MOUNT_SOURCE}. Exiting."
exit 1