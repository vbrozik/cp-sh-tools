#!/bin/sh

# cloud_uploader.sh
# This program uploads files to a cloud storage.

# Supported:
# * Amazon S3

# References:
# * https://awscli.amazonaws.com/v2/documentation/api/latest/reference/s3/index.html

work_dir=
incoming_dir=
aws_endpoint=
aws_bucket=
aws_destination="s3://$aws_bucket/"
log_dir="$work_dir/log"
log_file="$log_dir/cloud_uploader.log"
suffix_upload=.tgz


# program name, host name:
prog_name=cloud_uploader

# get parameters override
script_dir=$(dirname "$(readlink -f "$0")")
if test -r "$script_dir/${prog_name}_conf.sh" ; then
    # shellcheck source=/dev/null
    . "$script_dir/${prog_name}_conf.sh"
fi

# --------- common functions

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

aws_s3 () {
    aws s3 --endpoint-url "$aws_endpoint" "$@"
}

# ------------- The program

mkdir -p "$log_dir" || errexit "Cannot create log dir $log_dir."
cd "$incoming_dir" || errexit "Cannot change to incoming dir $incoming_dir."

for file in ./*"$suffix_upload" ; do
    if aws_s3 --quiet mv "$file" "$aws_destination" 2>"$log_file" ; then
        log "Uploaded $file"
    else
        log "Failed upload of $file"
    fi
done
