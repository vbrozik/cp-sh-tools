#!/bin/bash

# This script transfers logs from the Check Point log server to a remote machine
# advancing in the chronological order of the log closing time.
# The transfer pauses when there is not enough space on the remote machine.
# After transfer of each log file and empty file file_name.done is created
# on the remote machine to indicate that the log file has been transferred.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GB=$((1024 ** 3))

destination_user="user"
destination_host="remote_host"
destination_path="/var/log/ntt/original_logs"
file_of_transferred_files="$HOME/transferred_files.txt"
local_log_dir="$FWDIR/log"
destination_required_free_space=$((10 * GB))
config_file="log_transfer.conf"

if [[ -f "$SCRIPT_DIR/$config_file" ]] ; then
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/$config_file"
fi

errexit () {
    if [[ -z $1 ]] ; then
        local error="Unknown error"
    else
        local error=$1
    fi
    printf %s\\n "$error" >&2
    exit 1
}

mapfile -t log_files < <(
        fw lslogs -s etime |
        sed -nE '/fw.log$/d;s/^\s*[0-9]+[a-zA-Z]+\s+(.+).log$/\1/p'
    ) || errexit "Failed to get the list of log files"

if [[ -f "$file_of_transferred_files" ]] ; then
    mapfile -t transferred_files < "$file_of_transferred_files" ||
        errexit "Failed to read the list of transferred files"
fi

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

# Transfer the logs in the chronological order.
for log_file in "${log_files[@]}" ; do
    if is_transferred "$log_file" ; then
        continue
    fi
    while true ; do
        destination_free_space=$(get_destination_free_space)
        if (( destination_free_space > destination_required_free_space )) ; then
            transfer_files "$log_file"
            break           # next file
        else
            sleep 600      # wait 10 minutes and check again
        fi
    done
done
