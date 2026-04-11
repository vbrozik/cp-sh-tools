#!/bin/bash

# Useful shell snippets for various tasks.

# shellcheck disable=SC2317     # This file is not meant to be executed.
# shellcheck disable=SC2329     # This file is not meant to be executed.
# shellcheck disable=SC2034     # This file is not meant to be executed.
exit 0
#########################################################################


# Iterating over VSes

## Prepare list of VS IDs for iteration in the following snippets.

vs_ids=$(ip netns exec CTX00000 ip netns list-id | cut -d' ' -f2)

## Prepare list of VS IDs on Maestro.

vs_ids=$(
    asg stat vs all |
    awk -F'[[:space:]]*[|][[:space:]]*' '
        ! in_vs    && $2 ~ /^VSID$/    { in_vs = 1 ; next }
        in_vs == 1 && $0 ~ /^-{10}/    { in_vs = 2 ; next }
        in_vs == 2 && $0 ~ /^-{10}/    { exit }
        in_vs == 2 && $2 ~ /^[0-9]+$/  { print $2 }
        ')

## Prepare list of VS FWDIRs for iteration

fwdir0=${FWDIR%/CTX/*}
vs_ns_names=$(ip netns list | sed -En 's/(^CTX[0-9]+)\b.*/\1/p')
vs_fwdirs=$(
    for ns_name in $vs_ns_names ; do
        if [ "$ns_name" == CTX00000 ] ; then
            _suffix=
        else
            _suffix="/CTX/$ns_name"
        fi
        printf '%s\n' "$fwdir0$_suffix"
    done)

## Deactivate all VS instances on the cluster member

for vs in $vs_ids ; do
    vsenv "$vs"
    clusterXL_admin down
done
vsenv 0

## Show local SIC certificates of each VS

for vs in $vs_ids ; do
    vsenv "$vs"
    cpprod_util CPPROD_GetValue SIC MySICname ""
    cert_path=$(cpprod_util CPPROD_GetValue SIC CertPath "")
    cpopenssl pkcs12 -in "$cert_path" -nokeys -nomacver -passin pass: 2>/dev/null |
        cpopenssl x509 -noout -subject -serial -startdate
    echo
done
vsenv 0


## Get ICA IP address of each VS

for vs in $vs_ids ; do
    vsenv "$vs"
    cpprod_util CPPROD_GetValue SIC MySICname ""
    cpprod_util CPPROD_GetValue SIC ICAip ""
    grep ICAip "$CPDIR/registry/HKLM_registry.data"     # alternative reading
    echo
done
vsenv 0


## Set ICA IP address of each VS

new_ica_ip=

for vs in $vs_ids ; do
    vsenv "$vs"
    cp -v "$CPDIR/registry/HKLM_registry.data"{,.backup}
    cpprod_util CPPROD_SetValue SIC ICAip 1 "$new_ica_ip" 0
done
vsenv 0


## Put all VSes to DOWN state in a cluster

for vs in $vs_ids ; do
    vsenv "$vs"
    clusterXL_admin down
done
vsenv 0


# Iterating over SGMs

## Prepare list of SGM IDs for iteration in the following snippets.

sgm_ids=$(
    asg resource |
    awk -F'[[:space:]]*[|][[:space:]]*' '
        ! in_sgm  && $2 ~ /^Member ID$/        { in_sgm = 1 ; next }
        in_sgm    && $0 ~ /^\+-{20}/           { exit }
        in_sgm    && $2 ~ /^[12]_[0-9]{1,2}$/  { print $2 }
        ')

get_sgm_ids() {
    local chassis_id=$1
    printf '%s' "$sgm_ids" | grep "^${chassis_id}_" | paste -sd,
}

sgm_ids_ch1=$(
    asg resource |
    awk -F'[[:space:]]*[|][[:space:]]*' '
        ! in_sgm  && $2 ~ /^Member ID$/     { in_sgm = 1 ; next }
        in_sgm    && $0 ~ /^\+-{20}/        { exit }
        in_sgm    && $2 ~ /^1_[0-9]{1,2}$/  { print $2 }
        ')

sgm_ids_ch2=$(
    asg resource |
    awk -F'[[:space:]]*[|][[:space:]]*' '
        ! in_sgm  && $2 ~ /^Member ID$/     { in_sgm = 1 ; next }
        in_sgm    && $0 ~ /^\+-{20}/        { exit }
        in_sgm    && $2 ~ /^2_[0-9]{1,2}$/  { print $2 }
        ')

# Watching for an error message

fwdir0=${FWDIR%/CTX/*}
tail -vF "$fwdir0/log/fwk.elg" "$fwdir0/CTX/"CTX000*/log/fwk.elg |
    awk '/^==> / {file=$2; next} /cphwd_api_init.* failed/ {print file ":" $0}'
