#!/bin/bash -eux

# echo "==> reset cloud-init"
# cloud-init clean --logs

echo "==> remove SSH keys used for building"
rm -f /home/ubuntu/.ssh/authorized_keys
rm -f /root/.ssh/authorized_keys

echo "==> Remove the contents of /tmp and /var/tmp"
rm -rf /tmp/* /var/tmp/*

echo "==> Truncate any logs that have built up during the install"
find /var/log -type f -exec truncate --size=0 {} \;

echo "==> Remove /usr/share/doc/"
rm -rf /usr/share/doc/*

echo "==> Remove /var/cache"
find /var/cache -type f -exec rm -rf {} \;

echo "==> Cleanup apt"
apt-get -y autoremove
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "==> Force a new random seed to be generated"
rm -f /var/lib/systemd/random-seed

echo "==> Clear the history so our install isn't there"
rm -f /root/.wget-hsts

export HISTSIZE=0

rm -vf \
  /etc/network/interfaces.d/50-cloud-init.cfg \
  /etc/adjtime \
  /etc/hostname \
  /etc/hosts \
  /etc/ssh/*key* \
  /var/cache/ldconfig/aux-cache \
  /var/lib/systemd/random-seed \
  ~/.bash_history

fstrim --all --verbose

rm -f $(readlink -f $0)

echo "==> Clear out machine id"
truncate -s 0 /etc/machine-id
