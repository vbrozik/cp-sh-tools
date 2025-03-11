#!/bin/bash

# gateways.bash

# Library for obtaining managed gateways


# TODO:
# - get cluster members by cluster
# - more detailed filtering (e.g. recognize virtual switches)
#   - virtual switch - property "junction" is true, use show generic-object to obtain
# - selection of fields to return (IP address, UUID, etc.)
# - details-level full adds these interesting fields:
#   - "cluster-member-names" - e.g. VS cluster instances
# - add JSON output format
# - Add support for returning cluster members by cluster or returning cluster name.

# Get all gateways of a given type.
# arguments:
#   $1: gateway type
#           simple-gateway          - regular gateway
#           checkpoint-host
#           CpmiGatewayCluster      - gateway cluster (TODO: maybe only in older versions?)
#           CpmiVsxClusterNetobj    - VSX cluster
#           CpmiVsxClusterMember    - VSX cluster member
#           CpmiVsClusterMember     - VS cluster member instance of a VS
#           CpmiVsClusterNetobj     - VS (only on a VSX cluster?), includes virtual switches!
# limitations: Does not get more than 500 gateways. Can be fixed if needed.

# References:
# https://community.checkpoint.com/t5/Security-Gateways/Run-a-command-on-each-firewall-via-CPRID/m-p/231256/highlight/true#M44552
# similar shell code

get_gateways () {
    local gateway_type="$1"

    mgmt_cli -r true show gateways-and-servers limit 500 --format json |
        jq -r --arg gateway_type "$gateway_type" '
            .objects[] |
            select(.type == $gateway_type) |
            .name'
}
