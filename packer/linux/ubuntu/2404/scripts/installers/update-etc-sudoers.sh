echo "Updating secure_path in sudoers"

SUDOERS_PATH="/etc/sudoers"
sed -i.bak '/secure_path/d' $SUDOERS_PATH
# Add the secure_path with the /etc/environment path grab the PATH line, strip the leading PATH= and any quotes
pathFromEnv=$(grep -E '^PATH=' /etc/environment | cut -d= -f2- | tr -d '"')

echo "Defaults secure_path=\"$pathFromEnv\"" | sudo tee -a $SUDOERS_PATH > /dev/null
echo "Done! Updated secure_path in sudoers to $pathFromEnv"