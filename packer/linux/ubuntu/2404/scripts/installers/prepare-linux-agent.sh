#!/usr/bin/env bash
###############################################################################
# fix-walinuxagent.sh
# Upgrade Azure Linux Agent on Ubuntu 24.04 to the first SRU build that
# survives self‑update (2.11.1.4‑0ubuntu1~24.04.1), pin it, and disable
# further auto‑updates so waagent -deprovision works reliably.
###############################################################################
set -Eeuo pipefail
IFS=$'\n\t'

echo ">> Adding noble‑proposed repo (if absent)…"
if ! grep -Rq "noble-proposed" /etc/apt/sources.list*; then
  echo "deb http://azure.archive.ubuntu.com/ubuntu noble-proposed main universe restricted multiverse" \
    | tee /etc/apt/sources.list.d/noble-proposed.list
fi

echo ">> Pinning walinuxagent to proposed only…"
cat >/etc/apt/preferences.d/99-walinuxagent-proposed <<'EOF'
Package: walinuxagent
Pin: release a=noble-proposed
Pin-Priority: 1001
EOF

echo ">> Installing fixed walinuxagent build…"
apt-get update -y
apt-get install -y walinuxagent=2.11.1.4-0ubuntu1~24.04.1

echo ">> Holding package so later dist‑upgrades can’t undo the fix…"
apt-mark hold walinuxagent

echo ">> Disabling the agent’s self‑update feature…"
sed -i 's/^#\?\s*AutoUpdate.Enabled=.*/AutoUpdate.Enabled=n/' /etc/waagent.conf

echo ">> Restarting agent and verifying version…"
systemctl restart walinuxagent
sleep 5
waagent --version || { echo "ERROR: waagent not healthy"; exit 1; }

echo ">> walinuxagent patched and pinned successfully."
