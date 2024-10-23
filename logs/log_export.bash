#!/bin/bash

# Export Check Point logs from binary files to semicolon separated values.

source_dir=/var/log/ntt/original_logs
destination_dir=/var/log/ntt/exported_logs

errexit () {
    if [[ -z $1 ]] ; then
        local error="Unknown error"
    else
        local error=$1
    fi
    printf %s\\n "$error" >&2
    exit 1
}

cd "$source_dir" || errexit "Failed to change the directory to $source_dir"

available_logs=(*.done)

for log in "${available_logs[@]}" ; do
    log_basename=${log%.done}
    input_file="$log_basename".log
    if ! [[ -r "$input_file" ]] ; then
        echo "The log file $input_file is missing or not readable." 2>&1
        continue
    fi
    output_file="$destination_dir/$log_basename.csv"
    echo "Processing $log_basename"
    if ! fwm logexport -n -p -i "./$input_file" -o "$output_file" ; then
        echo "Export of $input_file failed." 2>&1
        continue
    fi
    if ! gzip "$output_file" ; then
        echo "Export to $output_file failed." 2>&1
        continue
    fi
    echo rm "$log_basename".*
done
