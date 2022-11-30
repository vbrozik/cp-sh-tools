#!/bin/sh

# Watch for changes in DNS resolution.
# After the change log the time and new values.

name="$1"
interval=5

previous_result=''
while true ; do
    time=$(date -Is)
    dig_res=$(dig +noall +answer +comments "$name")
    result=$(
        printf %s\\n "$dig_res" | sed -En 's/^;; .* (status: +\w+).*$/\1/p'
        printf %s\\n "$dig_res" | sed -En 's/.*\sIN\s+(CNAME\s+[a-zA-Z0-9_.-]+).*$/\1/p'
        printf %s\\n "$dig_res" | sed -En 's/.*\sIN\s+(A\s+[a-zA-Z0-9_.-]+).*$/\1/p'
    )
    if test "$result" != "$previous_result" ; then
        printf '\n%s --------------------\n' "$time"
        printf %s\\n "$result"
        previous_result="$result"
    fi
    sleep "$interval"
done
