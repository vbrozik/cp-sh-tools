#!/bin/sh

# get_skyline_config.sh

# The script generates a Skyline configuration file from a template and a certificate file.

# Dependencies:
# - rfc7468_to_single_line.sh: script to convert a PEM file to a single-line string
#   If the script is not in the PATH, it should be in the same directory as this script.


action=add
rfc7468_options=''
rfc7468_to_single_line_name=rfc7468_to_single_line.sh

script_dir="$(
    # shellcheck disable=SC2015
    cd "$(dirname "$0")" && pwd ||
    { printf %s\\n 'Failed to get script directory.' >&2 ; exit 1 ; }
    )"

if command -v "$rfc7468_to_single_line_name" > /dev/null 2>&1 ; then
    rfc7468_to_single_line_cmd="$rfc7468_to_single_line_name"
elif test -x "$script_dir/$rfc7468_to_single_line_name" ; then
    rfc7468_to_single_line_cmd="$script_dir/$rfc7468_to_single_line_name"
else
    printf %s\\n "Error: tool $rfc7468_to_single_line_name not found." >&2
    exit 1
fi

help_first_line='Usage: get_skyline_config.sh [--rebase] [-e] [-h] <config_directory>'

show_help () {
    
    cat <<EOF
$help_first_line

Generate a Check Point Skyline configuration JSON file from a template
and a certificate file. The generated file is sent to stdout.

Typical usage:
  sklnctl export --set \$(get_skyline_config.sh config_directory)
Updating the existing configuration:
  sklnctl export --set \$(get_skyline_config.sh --rebase config_directory)

config_directory: directory containing the following files:
  skyline_config_template.json - the main configuration file template
  cert.pem - the Prometheus server certificate file in PEM format

Options:
  --rebase    Rebase the configuration file to the default configuration.
  -e          Use the -e option for rfc7468_to_single_line.sh to
              use escaped newlines instead of simpler single-line output.
  -h, --help  Show this help message and exit.
EOF
}

for arg in "$@" ; do
    case "$arg" in
        --rebase)
            action=rebase
            shift
            ;;
        --add)
            action=add
            shift
            ;;
        -e)
            rfc7468_options='-e'
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            break
            ;;
    esac
done

if test $# -ne 1 ; then
    printf %s\\n "$help_first_line" >&2
    exit 1
fi

config_directory=$1
certificate_file="$config_directory"/cert.pem

sed \
    -e 's/{{action}}/'"$action"'/g' \
    -e 's%{{certificate}}%'"$(
        "$rfc7468_to_single_line_cmd" $rfc7468_options "$certificate_file"
        )"'%g' \
    "$config_directory"/skyline_config_template.json
