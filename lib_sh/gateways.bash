#!/bin/bash

# Library for obtaining managed gateways


# TODO:
# - get cluster members by cluster
# - more detailed filtering (e.g. recognize virtual switches)
#   - virtual switch - property "junction" is true, use show generic-object to obtain
# - selection of fields to return (IP address, UUID, etc.)
# - details-level full adds these interesting fields:
#   - "cluster-member-names" - e.g. VS cluster instances

# Get all gateways of a given type.
# arguments:
#   $1: gateway type
#           simple-gateway          - regular gateway
#           CpmiVsxClusterNetobj    - VSX cluster
#           CpmiVsxClusterMember    - VSX cluster member
#           CpmiVsClusterNetobj     - VS (on a VSX cluster), includes virtual switches!
# limitations: Does not get more thatn 500 gateways.
get_gateways () {
    local gateway_type="$1"

    mgmt_cli -r true show gateways-and-servers limit 500 --format json |
        jq -r --arg gateway_type "$gateway_type" '
            .objects[] |
            select(.type == $gateway_type) |
            .name'
}
