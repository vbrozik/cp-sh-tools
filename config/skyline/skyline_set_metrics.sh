#!/bin/bash

# skyline_set_metrics.sh

# The script updates the Check Point Skyline metrics configuration based on a list
# of excluded metrics. It uses the `sklnctl otelcol metrics --add` according
# to the documentation but also applies fixes using `sklnctl otelcol metrics --remove`
# to remove metrics that failed to be excluded.
# The script also checks if the metrics configuration does not contain any excluded metrics.


config_dir=$1
metrics_exclusions_file="$config_dir/metrics_exclusions.txt"

sklnctl otelcol metrics --reset

sklnctl otelcol metrics --is-default | grep -q ^true || {
    printf %s\\n 'Error: Failed to reset metrics configuration.' >&2
    exit 1
}

mkdir -p "$config_dir/tmp" || {
    printf %s\\n 'Failed to create tmp dir.' >&2
    exit 1
}

metrics_excluded_file="$config_dir/tmp/metrics_excluded.txt"

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

sklnctl otelcol metrics --is-default | grep -q ^true && {
    printf %s\\n 'Warning: metrics configuration is indicated as default.' >&2
}

echo "Metrics configuration updated. Excluded metrics saved to $metrics_excluded_file."
echo "Remaining metrics failed to be excluded (if any) are listed below:"
diff -u <(sort "$metrics_excluded_file") <(sklnctl otelcol metrics --show | sort)
