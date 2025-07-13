#!/bin/bash
#
# <UDF name="MINECRAFT_DOWNLOAD_URL" label="Minecraft dowload url"/>
# <UDF name="GAME_MODE" label="Game mode" oneOf="survival,creative" default="survival"/>
# <UDF name="DIFFICULTY" label="Difficulty" oneOf="peaceful,easy,normal,hard" default="easy"/>
# <UDF name="LEVEL_SEED" label="Level seed" default=""/>
# <UDF name="HOSTNAME" label="Hostname"/>
# <UDF name="OSS_BUCKET" label="Object storage bucket"/>
# <UDF name="OSS_ACCESS_KEY_ID" label="Object storage access key id"/>
# <UDF name="OSS_SECRET_ACCESS_KEY" label="Object storage secret key"/>
# <UDF name="OSS_ENDPOINT" label="Object storage endpoint"/>

set -e -o pipefail

exec > /var/log/stackscript.log
exec 2>&1

MCRCON_VERSION=0.7.2

export DEBIAN_FRONTEND=noninteractive

hostnamectl set-hostname $${HOSTNAME}

# Update and upgrade system packages
apt-get update
apt-get \
  -o Dpkg::Options::=--force-confold \
  -o Dpkg::Options::=--force-confdef \
  -y --allow-downgrades --allow-remove-essential --allow-change-held-packages \
  dist-upgrade

apt-get -y install pwgen

# Install Zulu SDK from their repos
# See https://docs.azul.com/core/zulu-openjdk/install/debian#install-from-azul-apt-repository
apt-get -y install gnupg curl
apt-key adv \
  --keyserver hkp://keyserver.ubuntu.com:80 \
  --recv-keys 0xB1998361219BD9C9

curl -O https://cdn.azul.com/zulu/bin/zulu-repo_1.0.0-3_all.deb
apt-get -y install ./zulu-repo_1.0.0-3_all.deb

apt-get update && apt-get -y install zulu19-jre

# AWS CLI
apt-get -y install unzip
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Download mcrcon
echo "Downloading mcrcon version $${MCRCON_VERSION} "
mkdir -p /opt/minecraft/tools/mcrcon
cd /opt/minecraft/tools/mcrcon
wget https://github.com/Tiiffi/mcrcon/releases/download/v$${MCRCON_VERSION}/mcrcon-$${MCRCON_VERSION}-linux-x86-64.tar.gz
tar xzf mcrcon-$${MCRCON_VERSION}-linux-x86-64.tar.gz
rm mcrcon-$${MCRCON_VERSION}-linux-x86-64.tar.gz

RCON_PASSWORD=$(pwgen 20)

# Create user
adduser minecraft
mkdir -p /opt/minecraft/server
cd /opt/minecraft/server

# Download minecraft
echo "Download from $${MINECRAFT_DOWNLOAD_URL}"
wget "$${MINECRAFT_DOWNLOAD_URL}"
echo "Download complete"

# Setup systemd service
cat <<- EOF > /etc/systemd/system/minecraft.service 
[Unit]
Description=Minecraft Server
After=network.target
[Service]
User=minecraft
Nice=5
KillMode=none
SuccessExitStatus=0 1
InaccessibleDirectories=/root /sys /srv /media -/lost+found
NoNewPrivileges=true
WorkingDirectory=/opt/minecraft/server
ReadWriteDirectories=/opt/minecraft/server
ExecStart=/usr/bin/java -Xmx1024M -Xms1024M -jar server.jar nogui
ExecStop=/opt/minecraft/tools/mcrcon/mcrcon -H 127.0.0.1 -P 25575 -p $${RCON_PASSWORD} stop
[Install]
WantedBy=multi-user.target
EOF

cat <<- EOF > /opt/minecraft/server/server.properties
${server_properties}
EOF

# Setup and configure backup and restore scripts
mkdir -p /home/minecraft/.aws
cat <<- EOF > /home/minecraft/.aws/credentials
[default]
aws_access_key_id = $${OSS_ACCESS_KEY_ID}
aws_secret_access_key = $${OSS_SECRET_ACCESS_KEY}
EOF
chmod 600 /home/minecraft/.aws/credentials
chown minecraft:minecraft /home/minecraft/.aws/credentials

cat <<-EOF > /etc/sudoers.d/minecraft
minecraft ALL=NOPASSWD:/usr/bin/systemctl stop minecraft,/usr/bin/systemctl start minecraft
EOF

# Backup script
cat <<- EOF > /usr/local/bin/minecraft-backup
#!/bin/bash
set -e -o pipefail

ARCHIVE=\$(hostname).tgz
S3_URL=s3://$${OSS_BUCKET}/worlds/\$ARCHIVE

echo "Backing up minecraft world data"

echo "Stopping minecraft"
sudo systemctl stop minecraft
sleep 5s
tar cvzf \$ARCHIVE world

echo "Uploading world data to \$S3_URL"
aws s3 --endpoint https://$${OSS_ENDPOINT} cp \$ARCHIVE \$S3_URL
rm \$ARCHIVE

echo "Starting minecraft"
sudo systemctl start minecraft
EOF
chmod +x /usr/local/bin/minecraft-backup

# Restore script
cat <<- EOF > /usr/local/bin/minecraft-restore
#!/bin/bash

set -e -o pipefail

ARCHIVE=\$(hostname).tgz
S3_URL=s3://$${OSS_BUCKET}/worlds/\$ARCHIVE

echo "Trying to restore minecraft world from \$S3_URL"
aws s3 --endpoint https://$${OSS_ENDPOINT} cp \$S3_URL \$ARCHIVE

echo "Stopping minecraft"
sudo systemctl stop minecraft
sleep 5s

[[ -d world.bak ]] && rm -rf world.bak
[[ -d world ]] && mv world world.bak
tar xvzf \$ARCHIVE
rm \$ARCHIVE

echo "Starting minecraft"
sudo systemctl start minecraft
EOF
chmod +x /usr/local/bin/minecraft-restore

# Basic configuration
echo "eula=true" > /opt/minecraft/server/eula.txt
chown -R minecraft:minecraft /opt/minecraft/
chmod 664 /etc/systemd/system/minecraft.service

# Update settings if needed
echo "Setting gamemode='$${GAME_MODE}'"
sed -i "s/^gamemode=.*/gamemode=$${GAME_MODE}/" /opt/minecraft/server/server.properties

echo "Setting rcon password"
sed -i "s/^rcon\.password=.*/rcon.password=$${RCON_PASSWORD}/" /opt/minecraft/server/server.properties

echo "Setting difficulty='$${DIFFICULTY}'"
sed -i "s/^difficulty=.*/difficulty=$${DIFFICULTY}/" /opt/minecraft/server/server.properties

echo "Setting level-seed='$${LEVEL_SEED}'"
sed -i "s/^level-seed=.*/level-seed=$${LEVEL_SEED}/" /opt/minecraft/server/server.properties

# Start minecraft
echo "Starting minecraft"

systemctl daemon-reload
systemctl enable minecraft
systemctl start minecraft
