#!/bin/bash

# Library for expanding targets specification to an array
# of target IP addresses.

# Input variables:
# - targets: array of target IP addresses if target[0] is expandable it will be expanded
# - groups_dir: directory where group files target_group_*.txt are stored,
#   default: ../conf/ relative to the script location

# Output variables:
# - targets: expanded array of target IP addresses

# Initialize input variables if not set.
: "${groups_dir:=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../conf/}"
: "${group_file_prefix:=target_group_}"
: "${group_file_suffix:=.txt}"

# TODO:
# - expand individual targets (no just the first one)
# - get targets from cluster objects
# - get all targets of a given category (e.g. all gateways) or pattern

targets_print () {
    local group_file group_name
    (
        cd "${groups_dir}" || {
            echo "Cannot cd to ${groups_dir}"
            exit 1
        }
        for group_file in "$group_file_prefix"*"$group_file_suffix" ; do
            group_name="${group_file#"$group_file_prefix"}"
            group_name="${group_name%"$group_file_suffix"}"
            echo "--- @$group_name"
            cat "$group_file"
            echo
        done
    )
}

targets_expand () {
    local target group_file

    target="${targets[0]}"
    if test "${target:0:1}" = "@" ; then
        # Target name starts with @, interpret as group name.
        if test "${target:1}" = "@" ; then
            # Target @@ causes listing all groups and not doing anything else.
            targets_print
            exit 0
        fi
        group_file="$groups_dir/$group_file_prefix${target:1}$group_file_suffix"
        if test -f "${group_file}" ; then
            mapfile -t targets < <(grep -Ev '^ *#|^ *$' "${group_file}")
        else
            echo "Group file ${group_file} not found"
            exit 1
        fi
    fi
}
