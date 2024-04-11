#!/bin/bash

# Check Point remote operations on multiple targets

# Usage: cpr <target> <command> [command_args]

# requirements:
#   - Gaia R81+ (tested on R81.10)
#   - bash 4.4+ (R81.10 contains bash 4.4.19)

# TODO:
# - get targets from cluster objects
# - get all targets of a given category (e.g. all gateways)
# - allow selecting VSes to execute a command on

if test "$#" -lt 1 -o "$1" = -h ; then
    # NOTE: The following here document must be indented by tabs, not spaces.
    cat <<- +++EOF+++
		cpr executes a command on multiple Check Point targets.

		Usage: cpr <target> <command> [args]

		    If <target> starts with @, it is interpreted as a group name.
		    The group content is read from a file named target_group_<group_name>.txt
		    in the same directory as this script.
		    Target @@ lists the existing groups.

		    On a VSX target you can execute certain commands on all VSes by using
		    the command: ip -all netns exec <command> [args]

		    ATTENTION: Command args are modified by replacing " with '.
		        Do not use double quotes around text to be expanded by the remote shell.

		    If functions like vsenv are needed, you need to start a login shell
		    or source /etc/bashrc. See the examples below.

		    Examples:
		        cpr @hu_pro ip -all netns exec fw ctl fast_accel show_table
		        cpr @hu_pro bash -c '. /etc/bashrc ; vsenv 2 ; du -sh \$FWDIR/log/'
		        cpr @hu_pro su -s /bin/bash -c 'vsenv 3 ; ip addr' - admin
		        cpr @hu_pro sh -c 'top -bn2 | awk "/^top / {f++} f==2" | head -n15'
		+++EOF+++
    exit 1
fi

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
targets=("$1")
shift

target="${targets[0]}"
if test "${target:0:1}" = "@" ; then
    # Target name starts with @, interpret as group name
    if test "${target:1}" = "@" ; then
        cd "${script_dir}" || exit 1
        for group_file in target_group_*.txt ; do
            group_name="${group_file#target_group_}"
            group_name="${group_name%.txt}"
            echo "--- @$group_name"
            cat "$group_file"
            echo
        done
        exit 0
    fi
    group_file="${script_dir}/target_group_${target:1}.txt"
    if test -f "${group_file}" ; then
        mapfile -t targets < <(grep -v '^#' "${group_file}")
    else
        echo "Group file ${group_file} not found"
        exit 1
    fi
fi

for target in "${targets[@]}"; do
    echo "--- target: ${target}"
    cprid_util -server "${target}" -verbose rexec -rcmd "$@"
done
