#!/bin/bash

# This script transfers logs from the Check Point log server to a remote machine
# advancing in the chronological order of the log closing time.
# The transfer pauses when there is not enough space on the remote machine.
# After transfer of each log file and empty file file_name.done is created
# on the remote machine to indicate that the log file has been transferred.

# Before running the script:

# 1. Setup passwordless SSH login from the local machine to the remote machine.
# shellcheck disable=SC2317     # Example code, not to be executed in this script
example_setup_passwordless_ssh () {
    ssh-keygen -t ed25519
    # On Gaia, non-admin administrators have their own home directories.
    # However, OpenSSH may reference the home directory specified in /etc/passwd,
    # defaulting to the admin's home. Let's create a symlink to the actual home.
    PHOME=$(getent passwd "$(whoami)" | cut -d: -f6)
    test "$HOME" = "$PHOME" || ln -vs "$PHOME/.ssh/" "$HOME/"
    ssh-copy-id user@remote_host
    ssh user@remote_host echo OK
}
unset -f example_setup_passwordless_ssh

# 2. Edit the configuration in the script or create a configuration file log_transfer.conf.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GB=$((1024 ** 3))

# --- Configuration ---

destination_user="user"
destination_host="remote_host"
destination_path="/var/log/ntt/original_logs"
file_of_transferred_files="$HOME/transferred_files.txt"
local_log_dir="$FWDIR/log"
destination_required_free_space=$((10 * GB))
wait_free_space_period=600
config_file="log_transfer.conf"

if [[ -f "$SCRIPT_DIR/$config_file" ]] ; then
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/$config_file"
fi

# --- Functions ---

# Show error message and exit.
errexit () {
    if [[ -z $1 ]] ; then
        local error="Unknown error"
    else
        local error=$1
    fi
    printf %s\\n "$error" >&2
    exit 1
}

# Get the free disk space on the destination machine and directory in bytes.
get_destination_free_space () {
    ssh -q -o BatchMode=yes -o ConnectTimeout=5 \
                "$destination_user@$destination_host" \
                "df --output=avail -B1 '$destination_path'" |
        tail -n1
}

# Check if the file was already transferred.
is_transferred () {
    local file=$1
    for transferred_file in "${transferred_files[@]}" ; do
        [[ $file == "$transferred_file" ]] && return 0
    done
    return 1
}

# Transfer the file to the destination machine.
transfer_files () {
    local file_basename=$1
    local file_path="$local_log_dir/$file_basename"
    local remote_file_path="$destination_path/"
    local remote_done_file_path="$destination_path/$file_basename.done"
    scp -q "$file_path".* "$destination_user@$destination_host:$remote_file_path" &&
        ssh -q -o BatchMode=yes -o ConnectTimeout=5 \
                    "$destination_user@$destination_host" \
                    "touch '$remote_done_file_path'" &&
        printf %s\\n "$file_basename" >> "$file_of_transferred_files"
}

# --- Main ---

# Get the list of log files (as basenames without the extension)
# in the chronological order of the log closing time.
mapfile -t log_files < <(
        fw lslogs -s etime |
        sed -nE '/fw.log$/d;s/^\s*[0-9]+[a-zA-Z]+\s+(.+).log$/\1/p'
    ) || errexit "Failed to get the list of log files"

# Read the list of files that were already transferred.
if [[ -f "$file_of_transferred_files" ]] ; then
    mapfile -t transferred_files < "$file_of_transferred_files" ||
        errexit "Failed to read the list of transferred files"
fi

# Transfer the logs in the chronological order.
for log_file in "${log_files[@]}" ; do
    if is_transferred "$log_file" ; then
        continue
    fi
    waiting_for_space=false
    while true ; do
        destination_free_space=$(get_destination_free_space)
        if (( destination_free_space > destination_required_free_space )) ; then
            $waiting_for_space &&
                echo "Enough space on the destination machine again. Resuming."
            transfer_files "$log_file"
            break                           # Continue with the next file.
        fi
        $waiting_for_space || echo "Waiting for space on the destination machine."
        waiting_for_space=true
        sleep $wait_free_space_period       # Wait, then check again for free space.
    done
done
