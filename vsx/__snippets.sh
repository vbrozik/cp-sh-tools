#!/bin/sh

# This file contains shell snippets for various tasks on VSX gateways.

# See also: generic/snippets.bash

# shellcheck disable=SC2154     # Variables defined outside of the snippets are used.
# shellcheck disable=SC2317     # This file is not meant to be executed or sourced.
# shellcheck disable=SC2329     # Functions defined in the snippets are not executed here.
# shellcheck disable=SC2034     # Variables defined in the snippets are not always used here.

exit 1

# ----- get FWDIR of VS0 -----

fwdir0=${FWDIR%/CTX/*}

# ----- list all network interfaces with IPv4 addresses on the VSX -----

ip -all netns exec ip -4 -o addr | sed -E '/^1: lo /d ; s/\\.*//'

# ------ connectivity check between cluster members, per VS ------

# Prepare command to set ping targets for other gateways in the cluster. Execute it on each member.
printf "addresses='%s'\n" "$(ip -o addr | sed -En '/ lo /d ; s/.*inet ([0-9.]+)\/.*/\1/p' | tr \\n \ )"

# Run the ping test:
ip -s neigh flush all ; for ip in $addresses ; do ping -i0.1 -c2 -w1 "$ip" ; done ; ip -s neigh

# Run arping test:
# Note that arping probably does not work on VSX gateways.TODO: check
get_outgoing_if () { ip -o route get "$1" | sed -En 's/.* dev ([^ ]+) .*/\1/p' ; }

for ip in $addresses ; do arping -f -c2 -w1 -I"$(get_outgoing_if "$ip")" "$ip" ; done ; ip -s neigh
