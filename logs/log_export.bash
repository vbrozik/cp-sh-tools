#!/bin/bash

# Export Check Point logs from binary files to semicolon separated values.
# The script processes logs from multiple source directories in a single run.
# To transfer the input logs from Check Point log servers, run log_transfer.bash
# on those log server.

# --- Configuration ---

# The directories below are relative to $working_directory.
working_directory=/var/log/ntt
# These suffixes are appended to the directories below.
# They allow to process logs from different sources in a single run.
dir_suffices=(_czdc _cedc)
# The original binary log files including their index and .done files.
input_dir_prefix=original_logs
# The directory to store the exported logs.
output_dir_prefix=exported_logs
# The temporary directory to store the exported logs before moving them to $output_dir_prefix.
tmp_dir_prefix=tmp_logs

# How long to wait after all logs have been processed and before checking for new logs.
wait_period=300
# How many times repeat the check with no new logs before exiting.
wait_cycles=5
# The maximum number of background processes (gzip) to run at the same time.
max_background_processes=2

# --- Functions ---

errexit () {
    if [[ -z $1 ]] ; then
        local error="Unknown error"
    else
        local error=$1
    fi
    printf %s\\n "$error" >&2
    exit 1
}

# Get sorted list of *.done files in the source directory.
# $1: The input directory relative to $working_directory and without the suffix
# $2: The suffix
get_available_logs () {
    local input_dir=$working_directory/$1$2/

    cd "$input_dir" || errexit "Failed to change the directory to $input_dir"
    available_logs=(*.done)
}

# Wait for the number of running processes to drop below the limit.
wait_for_processes () {
    local max_processes=$1
    while (( $(jobs -r | wc -l) > max_processes )) ; do
        sleep 0.2
    done
}

# Process files from one source directory.
# $1: The output directory, absolute path.
# The current workign directory is the source directory.
# $available_logs is an array of *.done files in the source directory.
process_source () {
    local destination_dir=$1
    local tmp_dir=$2

    for log in "${available_logs[@]}" ; do
        log_basename=${log%.done}
        input_file="$log_basename".log

        if ! [[ -r "$input_file" ]] ; then
            echo "The log file $input_file is missing or not readable." 2>&1
            continue
        fi

        tmp_output_file="$tmp_dir/$log_basename.csv"
        echo "Processing $log_basename"

        if ! fwm logexport -n -p -i "./$input_file" -o "$tmp_output_file" ; then
            echo "Export of $input_file failed." 2>&1
            continue
        fi
        echo            # fwm logexport does not print a newline.

        wait_for_processes "$max_background_processes"
        # Run gzip in the background and remove the original files after that.
        {
            if gzip "$tmp_output_file" && mv "$tmp_output_file.gz" "$destination_dir/" ; then
                rm "${log_basename}".*
            else
                echo "Export of $log_basename failed." >&2
            fi
        } &
    done
}

# --- Main ---

shopt -s nullglob

cycles_to_wait=$wait_cycles
while (( cycles_to_wait > 0 )) ; do
    logs_count=0

    for suffix in "${dir_suffices[@]}" ; do
        get_available_logs "$input_dir_prefix" "$suffix"
        logs_count=$((logs_count + ${#available_logs[@]}))
        if (( logs_count > 0 )) && (( cycles_to_wait < wait_cycles )) ; then
            echo "New logs found. Resetting the waiting cycle."
            cycles_to_wait=$wait_cycles
        fi
        process_source "$working_directory/$output_dir_prefix$suffix" "$working_directory/$tmp_dir_prefix$suffix"
    done

    if (( logs_count <= 0 )) ; then
        if (( cycles_to_wait == wait_cycles )) ; then
            echo "No logs to process. Waiting for new logs."
        fi
        cycles_to_wait=$((cycles_to_wait - 1))
        sleep $wait_period
    fi
done

wait -f
