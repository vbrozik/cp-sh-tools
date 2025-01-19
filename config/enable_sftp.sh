#!/bin/sh

# enable_sftp.sh

# Enable SFTP access with clish as a login shell.
# This is accomplished by setting the sftp subsystem in sshd to internal-sftp.
# The script also reloads the sshd service configuration to apply the changes.

# Limitations: The script makes the change only if the file contains
# the original uncommented sftp-server subsystem line.
# It was not tested:¨
# - if the line is not different in different versions of Gaia
# - how does the file change during upgrades

sshd_config_template="/etc/ssh/templates/sshd_config.templ"

# Edit the sshd configuration file template /etc/ssh/templates/sshd_config.templ
# Disable:
# Subsystem       sftp    /usr/libexec/openssh/sftp-server
# Enable:
# Subsystem       sftp    internal-sftp

sed -E -i.bak \
    -e 's%^\s*Subsystem\s+sftp\s+.+sftp-server%# &\nSubsystem       sftp    internal-sftp%' \
        "$sshd_config_template"
# Create new sshd_config from the template:
sshd_template_xlate < /config/active
service sshd reload
