#!/bin/bash

# skyline_set_metrics.sh

# The script updates the Check Point Skyline metrics configuration based on a list
# of excluded metrics. It uses the `sklnctl otelcol metrics --add` according
# to the documentation but also applies fixes using `sklnctl otelcol metrics --remove`
# to remove metrics that failed to be excluded.
# The script also checks if the metrics configuration does not contain any excluded metrics.


show_help () {
    cat <<EOF
Usage: $0 [-c] <config_directory>

Update the metrics configuration based on the exclusions list.

config_directory: directory containing the following files:
  metrics_exclusions.txt - list of metrics to be excluded from collection

Options:
  -c   Only check the configuration without updating it.
  -h   Show this help message and exit.
EOF
}


check_only=
while getopts "hc" opt ; do
    case "$opt" in
        h)
            show_help
            exit 0
            ;;
        c)
            check_only=1
            ;;
        *)
            echo "Unknown option: $opt" >&2
            show_help >&2
            exit 1
            ;;
    esac
done
shift $((OPTIND - 1))


config_directory=${1%/}
metrics_exclusions_file="$config_directory/metrics_exclusions.txt"

tmp_dir="$config_directory/tmp"
metrics_excluded_file="$tmp_dir/metrics_excluded.txt"


if [ "$check_only" != 1 ] ; then
    echo "=== Updating metrics configuration ==="

    mkdir -p "$tmp_dir" || {
        printf %s\\n 'Failed to create tmp dir.' >&2
        exit 1
    }

    sklnctl otelcol metrics --reset

    sklnctl otelcol metrics --is-default | grep -q ^true || {
        printf %s\\n 'Error: Failed to reset metrics configuration.' >&2
        exit 1
    }

    sklnctl otelcol metrics --show |
        grep -Ev "^ *($(
            sed -E 's/^ *([^ ]*) *$/\1/ ; s/\./\\./g ; s/_/[_.]/g' "$metrics_exclusions_file" |
            tr \\n \| )) *\$" > "$metrics_excluded_file"

    # shellcheck disable=SC2046     # word splitting wanted
    sklnctl otelcol metrics --add $(< "$metrics_excluded_file" tr '\n' ' ')

    # shellcheck disable=SC2046     # word splitting wanted
    sklnctl otelcol metrics --remove $(
        comm -13 <(sort "$metrics_excluded_file") <(sklnctl otelcol metrics --show | sort) |
        tr '\n' ' ')

    echo "Metrics configuration updated. Metrics with excluded ones removed saved to $metrics_excluded_file."
    echo "They should correspond to the current metrics configuration."
    echo
fi

echo "=== Checking metrics configuration ==="

if ! [ -r "$metrics_excluded_file" ] ; then
    printf %s\\n "Error: File with metrics excluded not found: %s" "$metrics_excluded_file" >&2
    printf %s\\n "Cannot check the metrics configuration." >&2
    exit 1
fi

sklnctl otelcol metrics --is-default | grep -q ^true && {
    printf %s\\n 'Warning: metrics configuration is indicated as default (even after the exclusion).' >&2
}

echo "Difference between the excluded metrics and the current configuration:"
diff -U0 \
        <(sort "$metrics_excluded_file") \
        <(sklnctl otelcol metrics --show 2> /dev/null | sort) |
    grep '^[+-]'
echo
