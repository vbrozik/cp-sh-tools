#!/bin/sh

# enable_sftp.sh

# Enable SFTP access with clish as a login shell.
# This is accomplished by setting the sftp subsystem in sshd to internal-sftp.
# The script also reloads the sshd service configuration to apply the changes.

# Recommendations for Maestro:
# 1. Put the script to the first SGM:   cat > /opt/ntt/bin/enable_sftp.sh
# 2. Distribute it:                     g_cp2blades /opt/ntt/bin/ -r -p
# 3. Run it on all SGMs:                g_all sh /opt/ntt/bin/enable_sftp.sh

# Limitations: The script makes the change only if the file contains
# the original uncommented sftp-server subsystem line.
# It was not tested:
# - if the line is not different in different versions of Gaia
# - how does the file change during upgrades

# Edits the sshd configuration file template /etc/ssh/templates/sshd_config.templ
# Disable:
# Subsystem       sftp    /usr/libexec/openssh/sftp-server
# Enable:
# Subsystem       sftp    internal-sftp

sshd_config_template="/etc/ssh/templates/sshd_config.templ"

sed -E -i.backup \
    -e 's%^\s*Subsystem\s+sftp\s+.+sftp-server%# &\nSubsystem       sftp    internal-sftp%' \
        "$sshd_config_template"

# Create new sshd_config from the template and apply it:
sshd_template_xlate < /config/active
service sshd reload
