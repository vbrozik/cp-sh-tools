# TODO

## Create installer script

* text file containing list of files to install including source and destination paths
* Installer shell script
  * Should be useable for installing from other repositories (e.g. with Python scripts) too
  * Should use just `curl` (not `git`)
  * Should provide installation profiles (like NTT-Gaia)

## Getting list of gateways from the management server database

<https://community.checkpoint.com/t5/API-CLI-Discussion/cprid-util-for-vsx/m-p/165909/highlight/true#M7369>

``` shell
mgmt_cli -r true -d 172.10.20.9 show-gateways-and-servers --format json details-level full |
    $CPDIR/jq/jq -r '.objects[] | select (.type=="CpmiVsxClusterMember") | [.name,."ipv4-address"] | @csv' |
    tr -d '"' | sed 's/,/ /' |
    while read -r gwname ip ; do
        mdsenv 172.10.20.9
        cprid_util -server $ip -verbose rexec -rcmd vsx stat -v |
            awk '$1 ~ /^[0-9]+$/ { print $1 }' |
            while read virtualSystemID ; do
                echo -e "vsenv $virtualSystemID\nenabled_blades" >> $gwname.txt
            done
        sed -i '1s/^/#!\/bin\/bash\nsource $CPDIR\/tmp\/.CPprofile.sh\nsource $FWDIR\/scripts\/vsenv.sh\n/' $gwname.txt
        cprid_util putfile -server $ip -local_file $gwname.txt -remote_file /var/tmp/$gwname.txt
        cprid_util -server $ip -verbose rexec -rcmd chmod +x /var/tmp/$gwname.txt
        cprid_util -server $ip -verbose rexec -rcmd bash -c /var/tmp/$gwname.txt
    done
```
