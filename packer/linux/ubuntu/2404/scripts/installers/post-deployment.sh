#!/usr/bin/env bash
###############################################################################
# File: post-deployment.sh
# Desc: Post‑deployment actions – compatible with Ubuntu 22.04
###############################################################################

set -Eeuo pipefail
IFS=$'\n\t'

source $HELPER_SCRIPT_FOLDER/etc-environment.sh
source $HELPER_SCRIPT_FOLDER/os.sh

# Helper for consistent error handling
error() { echo "ERROR: $*" >&2; exit 1; }
trap 'error "at line $LINENO"' ERR

###############################################################################
# 1. Move the post‑generation directory (if it exists)
###############################################################################
SOURCE_DIR="/imagegeneration/post-generation"
TARGET_DIR="/opt/post-generation"

echo ">> Moving $SOURCE_DIR to $TARGET_DIR …"
if [[ -d "$SOURCE_DIR" ]]; then
  mkdir -p "$(dirname "$TARGET_DIR")"
  mv -fv "$SOURCE_DIR" "$TARGET_DIR"
else
  echo "   WARNING: $SOURCE_DIR not found – skipping move"
fi

###############################################################################
# 2. File‑system permissions (safer defaults)
###############################################################################
# Give rwx to owner, rx to group/others; avoid 777 where possible
chmod -Rv 755 /opt

# /usr/share may contain immutable files (e.g. from snaps). Best‑effort only.
echo ">> Attempting chmod on /usr/share (may report errors) …"
chmod -Rv a+rX /usr/share || echo "   Ignoring chmod errors under /usr/share"

###############################################################################
# 3. Remove helper/installer folders (if defined)
###############################################################################
for dir_var in HELPER_SCRIPT_FOLDER INSTALLER_SCRIPT_FOLDER; do
  dir_val="${!dir_var:-}"
  if [[ -n "$dir_val" && -d "$dir_val" ]]; then
    echo ">> Removing $dir_val …"
    rm -rfv "$dir_val"
  fi
done

###############################################################################
# 4. Ensure IMAGE_FOLDER has the right perms (if defined)
###############################################################################
if [[ -n "${IMAGE_FOLDER:-}" && -d "$IMAGE_FOLDER" ]]; then
  echo ">> Setting permissions on $IMAGE_FOLDER …"
  chmod -v 755 "$IMAGE_FOLDER"
fi

###############################################################################
# 5. Normalise PATH in /etc/environment (replace, don’t append duplicates)
###############################################################################
current_path=$(grep -m1 '^PATH=' /etc/environment | cut -d= -f2- | tr -d '"')

# Remove existing PATH lines, then write a single quoted entry
sudo sed -i '/^PATH=/d' /etc/environment
printf 'PATH="%s"\n' "$current_path" | sudo tee -a /etc/environment >/dev/null

echo "   Updated /etc/environment:"
cat /etc/environment

###############################################################################
# 6. Update sudo secure_path to mirror the environment path
###############################################################################
path_from_env="$current_path"

# Remove any existing secure_path line, then append the new one
sudo sed -i '/secure_path/d' /etc/sudoers
printf 'Defaults secure_path="%s"\n' "$path_from_env" | sudo EDITOR='tee -a' visudo >/dev/null

echo "   secure_path updated to: $path_from_env"

###############################################################################
# 7. Execute any *.sh scripts dropped into $TARGET_DIR
###############################################################################
if [[ -d "$TARGET_DIR" ]]; then
  echo ">> Running post‑generation scripts in $TARGET_DIR …"
  find "$TARGET_DIR" -mindepth 1 -maxdepth 1 -type f -name "*.sh" -print -exec bash -eux {} \;
fi

###############################################################################
# 8. Completion message
###############################################################################
sudo apt-get update
sudo apt-get dist-upgrade -y
sudo apt-get install --yes --reinstall walinuxagent
sudo systemctl restart walinuxagent
waagent --version


if isUbuntu24; then
# Prevent needrestart from restarting the provisioner service.
# Currently only happens on Ubuntu 24.04, so make it conditional for the time being
# as configuration is too different between Ubuntu versions.
    sed -i '/^\s*};/i \    qr(^runner-provisioner) => 0,' /etc/needrestart/needrestart.conf
fi

echo ">> Post‑deployment actions completed successfully."
