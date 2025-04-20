#!/usr/bin/env bash
# ufw-azure.sh – lock everything down, then open only what Azure + DevOps need
set -Eeuo pipefail
IFS=$'\n\t'
echo ">>> Configuring UFW for Azure platform compatibility …"

# ----------------------------------------------------------------------
# 1. Azure host‑injected IP (WireServer, DNS, NTP)
# ----------------------------------------------------------------------
AZ_IP=168.63.129.16

ufw allow out proto tcp  to ${AZ_IP} port 80    comment 'WireServer REST'
ufw allow out proto tcp  to ${AZ_IP} port 32526 comment 'WireServer agent channel'
ufw allow out proto udp  to ${AZ_IP} port 53    comment 'Azure DNS UDP'
ufw allow out proto tcp  to ${AZ_IP} port 53    comment 'Azure DNS TCP'
ufw allow out proto udp  to ${AZ_IP} port 123   comment 'Azure host‑NTP'

# DHCP renewals (client 68 → server 67, broadcast)
ufw allow out proto udp from any port 68 to any port 67 comment 'DHCP client'

# ----------------------------------------------------------------------
# 2. Azure DevOps & general HTTPS
# ----------------------------------------------------------------------
# If you want maximum lockdown, replace this with the weekly IP list for
# dev.azure.com + storage.  Outbound‑only HTTPS is usually acceptable.
ufw allow out proto tcp to any port 443 comment 'HTTPS outbound (DevOps, Git, updates)'

# ----------------------------------------------------------------------
# 3. Enable firewall
# ----------------------------------------------------------------------
ufw --force enable
echo ">>> UFW status:"
ufw status verbose
