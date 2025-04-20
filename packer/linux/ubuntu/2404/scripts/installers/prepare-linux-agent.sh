#!/usr/bin/env bash
###############################################################################
# fix-walinuxagent.sh
#   Patch Azure Linux Agent on Ubuntu 24.04 so `waagent -deprovision`
#   no longer crashes with ModuleNotFoundError.
###############################################################################
set -Eeuo pipefail
IFS=$'\n\t'
export DEBIAN_FRONTEND=noninteractive

echo ">> Adding noble‑proposed from the primary archive …"
cat >/etc/apt/sources.list.d/noble-proposed.list <<'EOF'
deb http://archive.ubuntu.com/ubuntu noble-proposed main restricted universe multiverse
EOF

echo ">> Pinning walinuxagent to come from proposed only …"
cat >/etc/apt/preferences.d/99-walinuxagent-proposed <<'EOF'
Package: walinuxagent
Pin: release a=noble-proposed
Pin-Priority: 1001
EOF

echo ">> Updating apt lists …"
apt-get update -y

TARGET_VER="2.11.1.4-0ubuntu1~24.04.1"

echo ">> Installing walinuxagent ${TARGET_VER} (or newest in proposed) …"
if ! apt-get install -y "walinuxagent=${TARGET_VER}"; then
  echo "   Desired build not found, falling back to latest in proposed …"
  apt-get -t noble-proposed install -y walinuxagent
fi

echo ">> Holding the package to prevent accidental downgrade …"
apt-mark hold walinuxagent

echo ">> Disabling the agent’s self‑update feature …"
sed -i 's/^#\?\s*AutoUpdate.Enabled=.*/AutoUpdate.Enabled=n/' /etc/waagent.conf

echo ">> Restarting agent and verifying …"
systemctl restart walinuxagent
sleep 5
waagent --version || { echo 'ERROR: waagent not healthy!'; exit 1; }

echo ">> walinuxagent patched and pinned successfully."
