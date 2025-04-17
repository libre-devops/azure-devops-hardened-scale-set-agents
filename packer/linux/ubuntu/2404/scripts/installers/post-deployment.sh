#!/usr/bin/env bash
################################################################################
##  File: post-deployment.sh
##  Desc: Post‑deployment actions – verbose with plain echo statements
################################################################################
set -euxo pipefail          # stop on error, show commands, fail on pipe errors

echo ">> Move post‑generation directory to /opt …"
mv -fv /imagegeneration/post-generation /opt
echo "   mv exit code = $?"

echo ">> chmod -R 777 /opt …"
chmod -Rv 777 /opt || { echo "   chmod on /opt failed – exiting"; exit 1; }

echo ">> chmod -R 777 /usr/share … (may fail on immutable files)"
if chmod -Rv 777 /usr/share ; then
  echo "   /usr/share chmod completed"
else
  echo "   Ignoring chmod errors under /usr/share"
fi

echo ">> Remove helper + installer folders …"
rm -rfv "${HELPER_SCRIPT_FOLDER:?}" "${INSTALLER_SCRIPT_FOLDER:?}"

echo ">> Set permissions on \$IMAGE_FOLDER ($IMAGE_FOLDER) …"
chmod -v 755 "$IMAGE_FOLDER"

echo ">> Normalise PATH in /etc/environment …"
ENVPATH=$(grep -m1 '^PATH=' /etc/environment | cut -d= -f2- | tr -d '"')
echo "PATH=$ENVPATH" | sudo tee -a /etc/environment
echo "   New /etc/environment:"
cat /etc/environment

echo ">> Run any post‑generation scripts …"
/usr/bin/find /opt/post-generation \
  -mindepth 1 -maxdepth 1 -type f -name "*.sh" -print -exec bash -eux {} \;

echo ">> Read PATH back from /etc/environment …"
pathFromEnv=$(tail -n1 /etc/environment | cut -d= -f2-)
printf "   pathFromEnv: %s\\n" "$pathFromEnv"

echo ">> Update secure_path in /etc/sudoers …"
sudo sed -i.bak '/secure_path/d' /etc/sudoers
echo "Defaults secure_path=$pathFromEnv" | sudo tee -a /etc/sudoers
echo "   Final lines of /etc/sudoers:"
sudo tail -n 5 /etc/sudoers
