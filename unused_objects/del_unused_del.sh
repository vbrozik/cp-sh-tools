#!/bin/sh

# del_unused_del.sh

# usage:
# del_unused_del.sh [--do] directory ...
#   directory ...   -- list of directories containing type_*.csv lists to delete
#   --del           -- perform the deletion, otherwise just list the csv files

session_file="$(pwd)/.session.txt"

cleanup () {
    return_code="$?"
    echo "Cleaning up: session logout"
    mgmt_cli logout
    unset MGMT_CLI_SESSION_FILE
    rm "$session_file"
    trap - EXIT INT TERM
    if test "$return_code" -ne 0 ; then
        echo "Exiting with error code: $return_code"
        exit "$return_code"
    fi
}

if [ "$1" = "--del" ] ; then
    do_delete=1
    shift
else
    unset do_delete
fi

if [ -n "$do_delete" ] ; then
    mgmt_cli -r true login >"$session_file" || exit 1
    export MGMT_CLI_SESSION_FILE="$session_file"
    trap cleanup EXIT INT TERM
    mgmt_cli set session description "del_unused_del.sh: delete unused objects from: $*"
fi

for dirname ; do
    cd "$dirname" || { echo "Cannot cd into $dirname; skipping" ; continue ; }
    echo "=== $dirname"
    if [ -n "$do_delete" ] ; then
        mgmt_cli set session description "del_unused_del.sh: delete unused objects from: $dirname"
    fi
    for csv_file in type_*.csv ; do
        type="${csv_file%.csv}"
        type="${type#type_}"
        echo mgmt_cli delete "$type" --batch "$csv_file"
        if [ -n "$do_delete" ] ; then
            mgmt_cli delete "$type" --batch "$csv_file"
        fi
    done
    if [ -n "$do_delete" ] ; then
        echo Publishing
        sleep 15
        mgmt_cli publish || exit 1
        sleep 15
    fi
    cd ..
done
