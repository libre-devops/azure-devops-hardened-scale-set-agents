sudo sed -i 's/# AutoUpdate.Enabled=y/AutoUpdate.Enabled=y/g' /etc/waagent.conf
echo 'Starting Linux Sysprep'
systemctl restart walinuxagent
echo "Waiting for waagent to restart, sleeping 30s"
echo "Python3 used for waagent is $(which python3)"
for i in {1..30}
do
  echo "${i}s"
  sleep 1
done

sudo /usr/bin/python3 /usr/sbin/waagent -force -deprovision+user && export HISTSIZE=0 && sync