#!/bin/sh

# del_unused_gen.sh
# generate lists of objects to be deleted

# limitations:

# Check Point:
# show unused-objects does not show some object types:
#   - domain, group-with-exclusion
# works for these object types:
#   - address-range, dynamic-object, group, host, network, security-zone,
#   - service-dce-rpc, service-group, service-other, service-tcp, service-udp,
#   - wildcard
# possible workaround:
#   - show objects type group-with-exclusion
#   - where-used uid ...
# mgmt_cli -r true -f json show objects type group-with-exclusion | jq '.objects[].uid' | while read obj ; do echo testing $obj ; mgmt_cli -r true -f json where-used uid "$obj" | jq '."used-directly".total' ; done

# Supports running only on the management server.
# Uses root access: mgmt_cli -r true ...


step=500                                # list objects in groups of 500
out_prefix=del_list                     # output directory name prefix
session_file="$(pwd)/.session.txt"      # file to store API session key

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

mgmt_cli -r true login read-only true >"$session_file" || exit 1
export MGMT_CLI_SESSION_FILE="$session_file"
trap cleanup EXIT INT TERM

for offset in $(seq -w 0 "$step" 999999) ; do
    name="${out_prefix}-${offset}"
    list_json_file="list.json"
    if [ ! -d "$name/" ] ; then
        mkdir "$name/" || exit 1
    fi
    cd "$name/" || exit 1
    mgmt_cli -f json show unused-objects limit "$step" offset "$offset" >"$list_json_file" || exit 1
    total="$(jq .total "$list_json_file")"
    from="$(jq .from "$list_json_file")"
    to="$(jq .to "$list_json_file")"
    jq -r '.objects[] | .uid + "\t" + .type + "\t" + .name' "$list_json_file" > "list.txt" || exit 1
    while read -r object ; do
        uid=$(printf '%s\n' "$object" | cut -f1 -s)
        type=$(printf '%s\n' "$object" | cut -f2 -s)
        list_csv_file="type_${type}.csv"
        test -a "$list_csv_file" || printf '%s\n' "$uid" >"$list_csv_file"
        printf '%s\n' "$uid" >>"$list_csv_file" || exit 1
    done <list.txt
    rm list.txt
    printf %s\\n "Created: ${name}   $from-$to/$total"
    cd ..
    test "$to" = "$total" -o "$to" = null && break
done
