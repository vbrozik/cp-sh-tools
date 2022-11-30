#!/bin/sh

# format cplic db_print as CSV
# TODO: add header, use only awk, test in Gaia

cplic db_print -all |
    sed -nE 's/^([0-9.]+)\s+(\S+)\s+(.+CK-(\S+))\s*$/\1, \2, \3, \4/p' |
    awk -v FS=, -v OFS=, '{gsub(/-/, ":", $4)} {print}'

# recipes:

# list all unique CKs
# awk -F', ' '{print $4}' | sort -u

# list all unique CKs from SmartConsole license inventory
# awk -F, 'length($3) > 3 {print $3}' | sort -u

# info:

# cplic db_print shows all the CKs of licenses on the management server except
# - licenses in vsec_lic_cli (vsec_lic_cli view)
# - support contracts in the SmartUpdate repository
