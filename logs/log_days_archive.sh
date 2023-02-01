#!/bin/sh

# log_days_archive.sh

# For given days show archive size.
# Use option -d to show the number of days stored. The first and last day can be incomplete.

# The tool shows these columns:
# date disk_size archive_size time_of_print

# Excel to compute archive size in percent:
# =($C1 / $B1 / 10)
# The size is in 1000 B, the archive size is in B.

# Running in the background:
# nohup log_days_archive.sh </dev/null &> log_sizes.csv &
# It seems that using stdbuf -oL is not needed for line buffering.

# The script relies on the default file naming. File names cannot contain spaces.


SEPARATOR=' '

errexit () {
    printf %s\\n "Error: $*" >&2
    exit 1
}

cd "$FWDIR/log/" || errexit "Change to directory failed."
 
# Create list of days with logs.
days=$(
    find . -name '*.log*' |
    sed -nE 's%^\./(.+__)?([0-9]{4}-[0-9]{2}-[0-9]{2})_.*\.log.*%\2%p' |
    sort -u)

# Print the number of days.
if test "$1" = -d ; then
    echo "$days" | wc -l
fi

# Print size of logs per day in kB.
for day in $days ; do
    printf "%s$SEPARATOR%s$SEPARATOR%s$SEPARATOR%s\\n" "$day" \
        "$(du -c ./*"$day"_*.log* | sed -nE 's/^([0-9]+)[ \t]+total.*$/\1/p')" \
        "$(tar -cz ./*"$day"_*.log* | wc -c)" \
        "$(date +%T)"
done
