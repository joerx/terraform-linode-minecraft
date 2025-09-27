#!/bin/bash -eux

echo "==> waiting for cloud-init to finish"
while [ ! -f /var/lib/cloud/instance/boot-finished ]; do
    echo 'Waiting for Cloud-Init...'
    sleep 1
done

echo "==> updating apt cache"
sudo apt-get update -qq

echo "==> upgrade apt packages"
sudo apt-get upgrade -y -qq

echo "==> installing qemu-guest-agent"
sudo apt-get install -y -qq qemu-guest-agent

echo "==> MESSAGE is $MESSAGE"
echo \"MESSAGE is $MESSAGE\" > /etc/example.txt

apt-get -y purge snapd

cat <<EOF > /etc/cloud/cloud.cfg.d/99-nocloud-datasource.cfg
datasource_list:
- NoCloud
- None
EOF
