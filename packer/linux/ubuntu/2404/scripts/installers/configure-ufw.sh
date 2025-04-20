#!/usr/bin/env bash
# configure-ufw.sh – hardened UFW rules for Azure workloads
# -----------------------------------------------------
#   • Default deny all IN/OUT
#   • Open only Azure platform essentials + DevOps + Databricks + MySQL +
#     AVD + LDAP/LDAPS + SMB + SQL + Redis + RDP
#   • Optional extras are commented out for clarity
# -----------------------------------------------------
set -Eeuo pipefail
IFS=$'\n\t'
echo ">>> Configuring UFW for Azure‑compatible hardening …"

# ----------------------------------------------------------------------
# 1. Azure host‑injected IP (WireServer, DNS, NTP, DHCP)
# ----------------------------------------------------------------------
AZ_IP=168.63.129.16

ufw allow out proto tcp  to ${AZ_IP} port 80        comment 'WireServer REST'
ufw allow out proto tcp  to ${AZ_IP} port 32526     comment 'WireServer agent channel'
ufw allow out proto udp  to ${AZ_IP} port 53        comment 'Azure DNS UDP'
ufw allow out proto tcp  to ${AZ_IP} port 53        comment 'Azure DNS TCP'
ufw allow out proto udp  to ${AZ_IP} port 123       comment 'Azure host‑NTP'
ufw allow out proto udp from any port 68 to any port 67 comment 'DHCP client'

# ----------------------------------------------------------------------
# 2. DevOps / Git / general HTTPS
# ----------------------------------------------------------------------
ufw allow out proto tcp to any port 443  comment 'HTTPS outbound (DevOps, Git, updates)'
ufw allow out proto tcp to any port 22   comment 'Git over SSH'
ufw allow out proto tcp to any port 9418 comment 'Legacy git:// protocol'

# ----------------------------------------------------------------------
# 3. Core Azure PaaS ports
# ----------------------------------------------------------------------
ufw allow out proto tcp to any port 445  comment 'Azure Files SMB'
ufw allow out proto tcp to any port 1433 comment 'Azure SQL'
ufw allow out proto tcp to any port 3306 comment 'Azure MySQL client'
ufw allow out proto tcp to any port 33060 comment 'MySQL X‑Protocol (optional)'
ufw allow out proto tcp to any port 6380 comment 'Azure Redis TLS'
ufw allow out proto tcp to any port 6379 comment 'Azure Redis non‑TLS (if enabled)'
ufw allow out proto tcp to any port 5671 comment 'Service Bus AMQP (TLS)'
ufw allow out proto tcp to any port 5672 comment 'Service Bus AMQP (plain)'
ufw allow out proto tcp to any port 9093 comment 'Event Hubs Kafka SSL'
ufw allow out proto tcp to any port 22   comment 'SFTP‑enabled Storage'

# ----------------------------------------------------------------------
# 4. LDAP / LDAPS (client side)
# ----------------------------------------------------------------------
ufw allow out proto tcp to any port 389  comment 'LDAP client'
ufw allow out proto udp to any port 389  comment 'LDAP client UDP'
ufw allow out proto tcp to any port 636  comment 'LDAPS client'
ufw allow out proto udp to any port 636  comment 'LDAPS client UDP'
# Uncomment next lines if the VM HOSTS LDAP/LDAPS
# ufw allow in proto tcp to any port 389  comment 'LDAP server'
# ufw allow in proto tcp to any port 636  comment 'LDAPS server'

# ----------------------------------------------------------------------
# 5. Azure Databricks (workspace, metastore, PL back‑end, control ports)
# ----------------------------------------------------------------------
for p in 443 3306 6666 8443:8451; do
    ufw allow out proto tcp to any port $p comment "Databricks $p"
done

# ----------------------------------------------------------------------
# 6. Azure Virtual Desktop + RDP
# ----------------------------------------------------------------------
ufw allow out proto tcp to any port 443  comment 'AVD control plane'
ufw allow out proto tcp to any port 1688 comment 'AVD KMS activation'
ufw allow out proto tcp to any port 3389 comment 'Outbound RDP client'
ufw allow out proto tcp to any port 3390 comment 'AVD Shortpath TCP (out)'
ufw allow out proto udp to any port 3390 comment 'AVD Shortpath UDP (out)'
# If this VM is an AVD session‑host & you enabled Shortpath:
# ufw allow in  proto udp to any port 3390 comment 'AVD Shortpath UDP (in)'
# If the VM LISTENS for classic RDP:
# ufw allow in  proto tcp to any port 3389 comment 'Inbound RDP host'

# ----------------------------------------------------------------------
# 7. Enable & show status
# ----------------------------------------------------------------------
ufw --force enable
echo ">>> UFW status:"
ufw status verbose
