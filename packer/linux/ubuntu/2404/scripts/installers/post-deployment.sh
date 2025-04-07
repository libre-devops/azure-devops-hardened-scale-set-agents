#!/bin/bash -e
################################################################################
##  File: post-deployment.sh
##  Desc: Post deployment actions
################################################################################

mv -f /imagegeneration/post-generation /opt

echo "chmod -R 777 /opt"
chmod -R 777 /opt
echo "chmod -R 777 /usr/share"
chmod -R 777 /usr/share

# remove installer and helper folders
rm -rf $HELPER_SCRIPT_FOLDER
rm -rf $INSTALLER_SCRIPT_FOLDER
chmod 755 $IMAGE_FOLDER

# Remove quotes around PATH
ENVPATH=$(grep 'PATH=' /etc/environment | head -n 1 | sed -z 's/^PATH=*//')
ENVPATH=${ENVPATH#"\""}
ENVPATH=${ENVPATH%"\""}
echo "PATH=$ENVPATH" | sudo tee -a /etc/environment
echo "Updated /etc/environment: $(cat /etc/environment)"

# https://github.com/actions/virtual-environments/blob/main/docs/create-image-and-azure-resources.md#post-generation-scripts
find /opt/post-generation -mindepth 1 -maxdepth 1 -type f -name "*.sh" -exec bash {} \;


# get path information from /etc/environment
pathFromEnv=$(cut -d= -f2 /etc/environment | tail -1)
printf "pathFromEnv:\n %s\n" "$pathFromEnv"

# update /etc/sudoers secure_path
sed -i.bak "/secure_path/d" /etc/sudoers
echo "Defaults secure_path=$pathFromEnv" >> /etc/sudoers

# debug
cat /etc/sudoers
