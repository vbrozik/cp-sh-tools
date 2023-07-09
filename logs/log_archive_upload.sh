#!/bin/bash

# log_archive_upload.sh
#
# This program uploads logs to an archive directory on a remote system.
#
# On the remote system the logs are supposed to be uploaded to a cloud storage
# service using a separate program cloud_uploader.sh.

# Repository:
# https://raw.githubusercontent.com/vbrozik/cp-sh-tools/main/logs/log_archive_upload.sh

# Arguments:
#   -n | --dry-run   Do not upload anything, just show what would be uploaded.
#   -m | --max-days  Maximum number of days to upload. (Default: 1000)
#                    All available days will be logged anyway.
#   -h | --help      Show help and exit.

# Installation:
if false ; then     # installation commands, do not execute in this file

bin_dir=/opt/NTT/bin

mkdir -p "$bin_dir/"

# TODO: Avoid bypassing certificate validation (-k).
# curl 7.61 in Gaia R81.10 does not support --output-dir (added in 7.73)
# curl --output-dir "$bin_dir/" -O ...
(
cd "$bin_dir/" &&
curl -k -O \
    https://raw.githubusercontent.com/vbrozik/cp-sh-tools/main/logs/log_archive_upload.sh
)

chmod +x "$bin_dir/log_archive_upload.sh"

cat >"$bin_dir/log_archive_upload_conf.sh" <<'+++EOF'
upload_dir=/aplikace/cp_log_arch/incoming
upload_target=cp_log_arch@machine-name
+++EOF

# Configure password-less SSH login to the upload target.
# Create the directories on the upload target.

mkdir -p /var/log/log_arch

# test:

"$bin_dir/log_archive_upload.sh" -n
"$bin_dir/log_archive_upload.sh"

clish -c 'add cron job log_arch command "'\
"$bin_dir/log_archive_upload.sh"' >>/var/log/log_arch/cron.log 2>&1" recurrence daily time 2:25'
clish -c 'save config'

fi                # end of installation commands

# Limitations:
# * The algorithm expects that for every day there will be at least some logs.
#   This is because the sequence of dates is created only from dates
#   of existing logs.
#   TODO: next_day=$(date -d "$day + 1 day" +%Y-%m-%d)
# * No protection against parallel running of multiple instances of the script
#   which will most probably cause failures.
#   TODO: Implement locking with reliable removal of stale lock and stale
#   process.
# * No high availability of upload targets.
#   TODO: Allow specifying multiple targets. Upload to the available one.
# * Only most CPU and disk intensive commands are run with lowered priority.
#   TODO: Allow lowering priority of the whole script.

# Author:  Václav Brožík


# shellcheck source=/dev/null
. /etc/profile.d/CP.sh

# region: configuration -----------------------------------------------

# directory containing logs and working files:
work_dir=/var/log/log_arch
tmp_dir="$work_dir/tmp"
# log file:
log_file="$work_dir/log_arch.log"
# file with sorted dates of logs uploaded last time:
last_dates="$work_dir/last_dates.txt"
# do not upload yesterday and today log files:
newest_upload_date="$(date -d '2 days ago' +%Y-%m-%d)"

# parameters of remote system:
# remote upload directories and SSH target must be added
upload_dir=
upload_target=
# how much disk free space should be on the target after upload
upload_keep_free=16000000000

# program name, host name:
prog_name=log_archive_upload
hostname="$(hostname -s)"

ISO_DATE_ERE='[0-9]{4}-[0-9]{2}-[0-9]{2}'

# get parameters override
script_dir="$(dirname "$(readlink -f "$0")")"
if test -r "$script_dir/${prog_name}_conf.sh" ; then
    # shellcheck source=/dev/null
    . "$script_dir/${prog_name}_conf.sh"
fi

# endregion: configuration -----------------------------------------------

# region: common functions -----------------------------------------------

# Print error message and exit the program.
errexit () {
    case "$2" in
        *[!0-9]*)
            exit_code=''
            message='Error (%s continuing)'
            ;;
        *)
            exit_code="$2"
            test -z "$exit_code" && exit_code=1
            message='Fatal error (%s exiting)'
            ;;
    esac
    printf "$message: %s\\n" "$prog_name" "$1" >&2
    if test -w "$log_file" && ! test "$log_file" = /dev/null ; then
        log "$(printf "$message: %s" "$prog_name" "$1")"
    fi
    if test -n "$exit_code" ; then
        exit "$exit_code"
    fi
}

# Print date for logging.
log_time () {
    # Date in ISO 8601 format with time zone:
    date -Is
}

# Log a message.
log () {
    test -e "$log_file" || touch "$log_file"
    if ! test -w "$log_file" ; then
        log_file=/dev/stderr
        errexit "Cannot write to log file: $log_file." n >&2
    fi
    printf '%s %s: %s\n' "$(log_time)" "$prog_name" "$*" >> "$log_file"
}

# Test if one of lines in $1 matches ERE $2
contains () {
    printf %s "$1" | grep -Eq "$2"
}

# Convert items on lines to items on a single line separated by spaces.
lines_to_list () {
    printf %s "$1" | tr \\n ' '
}

# Delete the files which exist.
rm_if_exists () {
    for file in "$@" ; do
        test -e "$file" && rm "$file"
    done
}

# Run the command dry if $dry_run is not empty.
# Status code of the command is preserved.
# In case of dry run, the status code is always 0.
run_command () {
    if test -z "$dry_run" ; then
        # test -n "$verbose" && log 'Running:' "$*"
        "$@"
    else
        log 'Dry run:' "$*"
    fi
}

# endregion: common functions -----------------------------------------------

# --------- the program

set -o pipefail

# Parse arguments.
dry_run=
parameters_info=
max_days=1000
while test -n "$1" ; do
    case "$1" in
        -n|--dry-run)
            dry_run=1
            parameters_info="$parameters_info [dry-run]"
            log_file=/dev/stderr
            ;;
        -m|--max-days)
            max_days="$2"
            printf '%s\n' "$max_days" | grep -Eq '^[0-9]+$' ||
                errexit "Invalid max-days value: $max_days"
            shift
            parameters_info="$parameters_info [max-days=$max_days]"
            ;;
        -h|--help)
            printf 'Usage: %s [-h|--help] [-n|--dry-run] [-m|--max-days N]\n' "$0"
            exit
            ;;
        *)
            errexit "Unknown argument: $1"
            ;;
    esac
    shift
done

log "INFO: Program started${parameters_info}."

if ! test -e "$work_dir/" ; then
    mkdir -p "$work_dir/" || errexit "Creating work directory $work_dir failed."
    log "INFO: Missing work directory $work_dir was created."
fi

if ! test -e "$tmp_dir/" ; then
    mkdir -p "$tmp_dir/" || errexit "Creating tmp directory $tmp_dir failed."
    log "INFO: Missing tmp directory $tmp_dir was created."
fi

cd "$FWDIR/log/" || errexit "Change to Check Point log directory failed."
 
# Create list of days with logs.
days_available="$(
    find . -name '*.log*' |
    sed -nE 's%^\./(.+__)?('"$ISO_DATE_ERE"')_.*\.log.*%\2%p' |
    sort -u)"
# Create list of days to upload. This list will be reduced.
days_to_upload="$days_available"
days_available_list="$(lines_to_list "$days_available")"
if test -n "$dry_run" ; then
    log "INFO: Log days present $(printf '%s' "$days_available_list" | wc -w): $days_available_list"
fi

touch "$last_dates" || errexit "Cannot update file $last_dates"

# date of the latest uploaded logs
last_uploaded="$(grep -E "^$ISO_DATE_ERE$" "$last_dates" | tail -n1)"
last_uploaded="${last_uploaded:-<no date recorded>}"
if test -n "$dry_run" ; then
    log "INFO: Last uploaded date: $last_uploaded"
fi

# Check if last_uploaded is in days_available, remove days till last_uploaded.
if contains "$days_available" "^$last_uploaded" ; then
    days_to_upload="$(printf %s "$days_to_upload" | sed "0,/^$last_uploaded/d")"
else
    log \
        "Some logs may be missing in the archive. Last uploaded date $last_uploaded"\
        "is not in the available logs: $(list_to lines "$days_available")."
fi
if test -n "$dry_run" ; then
    log "INFO: Days to upload: $(lines_to_list "$days_to_upload")"
fi

# Check if newest_upload_date is in days_available.
# Remove dates after newest_upload_date.
if contains "$days_to_upload" "^$newest_upload_date" ; then
    days_to_upload="$(printf %s "$days_to_upload" | sed "/^$newest_upload_date/q")"
else
    log \
        "WARNING: Not uploading. Newest date allowed to upload $newest_upload_date"\
        "not in available not uploaded logs: $(lines_to_list "$days_to_upload")."
    exit 0
fi

if test -z "$days_to_upload" ; then
    log "WARNING: Nothing to upload. Available logs: $(lines_to_list "$days_available")"
    exit 0
fi

# Show what was uploaded at the end or in case of interruption.
log_uploads () {
    log \
        "INFO: Uploaded $uploaded_count log dates"\
        "from $(printf %s "$days_to_upload" | head -n1)"\
        "till $last_uploaded."
    exit
}

# Upload logs as tar archives.
if test -n "$(ls -A "$tmp_dir/")" ; then
    rm "$tmp_dir/"*
fi
file_block_size="$(stat -c%B "$tmp_dir/")"
test "$?" -ne 0 && errexit "Cannot get block size of $tmp_dir/."
uploaded_count=0
last_uploaded=none
printf '=== uploading on %s\n' "$(date +%Y-%m-%d)" >> "$last_dates"
trap log_uploads INT
for date in $days_to_upload ; do
    log "Uploading day $date"

    arch_name="${date}_$hostname.tgz"
    arch_name_incomplete="$arch_name.incomplete"
    full_arch_name="$tmp_dir/$arch_name"
    run_command nice -n19 ionice -c3 tar -czf "$full_arch_name" ./*"$date"_*.log*
    if test "$?" -ne 0 ; then
        test -e "$full_arch_name" && rm "$full_arch_name"
        log "Tar failed for $full_arch_name. Quitting for now."
        break
    fi

    # The rest is not implemented for dry run.
    if test -n "$dry_run" ; then
        log "INFO: Dry run (not simulating the rest): checking disk space, uploading $full_arch_name."
        last_uploaded="$date"
        uploaded_count=$((uploaded_count + 1))
        if test "$uploaded_count" -ge "$max_days" ; then
            log "INFO: Dry run: reached max-days=$max_days, quitting."
            break
        fi
        continue
    fi

    # Test if there is enough disk space on the target.
    file_size="$(( $(stat -c%b "$full_arch_name") * file_block_size ))"
    remote_free="$(
        ssh -oLogLevel=error "$upload_target" df -B1 --output=avail "$upload_dir/" |
        sed 1d )"
    test "$?" -ne 0 && errexit "Cannot get free space on $upload_target:$upload_dir/."
    if test "$((file_size + upload_keep_free))" -ge "$remote_free" ; then
        printf '%s\n' "=== no space on upload target, quitting for now" >> "$last_dates"
        log "Not enough disk space on upload target $remote_free. Quitting for now."
        rm "$full_arch_name"
        break
    fi

    # NOTE: Using @ prefix to quiet batch commands is available only since OpenSSH 7.9.
    # Gaia R81.10 contains OpenSSH 7.8.
    if ! printf 'put %s %s\n' "$full_arch_name" "$arch_name_incomplete" |
            nice -n19 ionice -c3 \
            sftp -oLogLevel=error -b- "$upload_target":"$upload_dir/" >/dev/null
    then
        printf '%s\n' "=== upload failed, quitting for now" >> "$last_dates"
        log "Upload failed for $full_arch_name. Quitting for now."
        rm "$full_arch_name"
        break
    fi

    if ! printf 'rename %s %s\n' "$arch_name_incomplete" "$arch_name" |
            sftp -oLogLevel=error -b- "$upload_target":"$upload_dir/" >/dev/null
    then
        printf '%s\n' "=== rename after upload failed, quitting for now" >> "$last_dates"
        log "Upload failed for $full_arch_name. Quitting for now."
        rm_if_exists "$full_arch_name"
        break
    fi

    rm_if_exists "$full_arch_name"

    last_uploaded="$date"
    printf '%s\n' "$last_uploaded" >> "$last_dates"
    uploaded_count=$((uploaded_count + 1))
    if test "$uploaded_count" -ge "$max_days" ; then
        log "INFO: Reached max-days=$max_days, quitting."
        break
    fi
    sleep 5
done

log_uploads
