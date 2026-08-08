#!/bin/sh

# skyline_install.sh

CP_OTELCOL=/opt/CPotelcol


show_help () {
    cat <<EOF
Usage: skyline_install.sh [-h] [-d] <config_directory>

Install Check Point Skyline configuration and exceptions.

config_directory: directory containing the following files:
  skyline_config_template.json - the main configuration file template
  cert.pem - the Prometheus server certificate file in PEM format
  metrics_exclusions.txt - list of metrics to be excluded from collection
  no_proxy - optional file with proxy exceptions

Options:
  -h   Show this help message and exit.
  -d   Dry run. Show the commands that would be executed without actually executing them.
EOF
}

dry_run_prefix=

while getopts "hd" opt ; do
    case "$opt" in
        h)
            show_help
            exit 0
            ;;
        d)
            dry_run_prefix="echo"
            ;;
        *)
            show_help >&2
            exit 1
            ;;
    esac
done
shift $((OPTIND - 1))

if [ "$#" -ne 1 ] ; then
    echo "Error: Missing required argument <config_directory>." >&2
    show_help >&2
    exit 1
fi

config_directory=$1

script_dir="$(
    # shellcheck disable=SC2015
    cd "$(dirname "$0")" && pwd ||
    { printf %s\\n 'Error: Failed to get script directory.' >&2 ; exit 1 ; }
    )"

echo "Going to install Skyline"
echo
echo "=== Proxy exceptions ==="

if [ -r "$config_directory/no_proxy" ] ; then
    $dry_run_prefix cp -av "$config_directory/no_proxy" "$CP_OTELCOL" || {
        printf %s\\n 'Error: Failed to copy no_proxy file.' >&2
        exit 1
    }
else
    printf %s\\n "Info: no_proxy file not found in $config_directory. Skipping."
fi

echo
echo "=== Metrics exceptions ==="

$dry_run_prefix "$script_dir/skyline_set_metrics.sh" "$config_directory" || {
    printf %s\\n 'Error: Failed to set metrics exceptions.' >&2
    exit 1
}

echo
echo "=== Skyline configuration ==="

$dry_run_prefix sklnctl export --set "$("$script_dir/skyline_get_config.sh" "$config_directory")" || {
    printf %s\\n 'Error: Failed to set Skyline configuration.' >&2
    exit 1
}
