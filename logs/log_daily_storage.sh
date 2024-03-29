#!/bin/sh

# log_daily_storage.sh

# Show daily storage usage of traffic logs inside $FWDIR/log
# The sizes are shown in KB.

# Use option -d to show the number of days stored. The first and last day can be incomplete.

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
    sort -u )

# Print the number of days.
if test "$1" = -d ; then
    echo "$days" | wc -l
fi

# TODO: Compute the average size of logs per day.
# Store sizes in an array. Remove the first and last day.
# Compute the number of whole weeks.
# Compute the average size of logs per day in all the last whole weeks.

# Print size of logs per day in kB.
for day in $days ; do
    printf "%s$SEPARATOR" "$day"
    du -c ./*"$day"_*.log* |
        sed -nE 's/^([0-9]+)[ \t]+total.*$/\1/p'
done
