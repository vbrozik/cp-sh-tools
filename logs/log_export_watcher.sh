#!/bin/sh

# Watch the progress of log export done by log_export.bash and log_transfer.bash.

cd /var/log/ntt/ || exit 1

# shellcheck disable=SC2016
watch \
    du -shL -- *_logs_* \; echo \; \
    df -h /var/log/ \; echo \; \
    sh -c '
    shopt -s nullglob
    for prefix in original exported tmp ; do
        for suffix in czdc cedc ; do
            echo === ${prefix}_logs_$suffix
            ls -str ${prefix}_logs_$suffix | tail -n3
        done
    done'
