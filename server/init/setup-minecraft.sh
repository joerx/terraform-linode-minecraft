#!/bin/bash

set -e -o pipefail

>&2 echo "Setting up minecraft server"
>&2 echo "============================="
stat /etc/default/minecraft-server

>&2 echo "Loading defaults:"
>&2 echo "------------------"
cat "/etc/default/minecraft-server"

. /etc/default/minecraft-server

>&2 echo "------------------"
>&2 echo "GAME_MODE=${GAME_MODE}"
>&2 echo "DIFFICULTY=${DIFFICULTY}"
>&2 echo "------------------"

# AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install

# Corretto JDK
wget -O - https://apt.corretto.aws/corretto.key | gpg --dearmor -o /usr/share/keyrings/corretto-keyring.gpg && \
echo "deb [signed-by=/usr/share/keyrings/corretto-keyring.gpg] https://apt.corretto.aws stable main" | tee /etc/apt/sources.list.d/corretto.list
apt-get update && apt-get install -y java-21-amazon-corretto-jdk

# Download mcrcon
>&2 echo "Downloading mcrcon version ${MCRCON_VERSION}"
mkdir -p /opt/minecraft/tools/mcrcon
cd /opt/minecraft/tools/mcrcon
wget https://github.com/Tiiffi/mcrcon/releases/download/v${MCRCON_VERSION}/mcrcon-${MCRCON_VERSION}-linux-x86-64.tar.gz
tar xzf mcrcon-${MCRCON_VERSION}-linux-x86-64.tar.gz
rm mcrcon-${MCRCON_VERSION}-linux-x86-64.tar.gz

mkdir -p /opt/minecraft/.config
RCON_PASSWORD=$(pwgen 20)
echo "${RCON_PASSWORD}" > /opt/minecraft/.config/mcrcon.pw && chmod 600 /opt/minecraft/.config/mcrcon.pw

# Download minecraft
mkdir -p /opt/minecraft/server && chown minecraft:minecraft /opt/minecraft/server
cd /opt/minecraft/server

>&2 echo "Download from ${MINECRAFT_DOWNLOAD_URL}"
wget "${MINECRAFT_DOWNLOAD_URL}"
>&2 echo "Download complete"


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
ExecStop=/opt/minecraft/tools/mcrcon/mcrcon -H 127.0.0.1 -P 25575 -p ${RCON_PASSWORD} stop
[Install]
WantedBy=multi-user.target
EOF


# Write default server.properties
cat <<- EOF > /opt/minecraft/server/server.properties
#Minecraft server properties
#(File modification date and time)
enable-jmx-monitoring=false
level-seed=${LEVEL_SEED}
gamemode=${GAME_MODE}
enable-command-block=false
enable-query=false
generator-settings={}
enforce-secure-profile=true
level-name=${LEVEL_NAME}
motd=${HOSTNAME}
query.port=25565
pvp=true
generate-structures=true
max-chained-neighbor-updates=1000000
difficulty=${DIFFICULTY}
network-compression-threshold=256
max-tick-time=60000
require-resource-pack=false
use-native-transport=true
max-players=${MAX_PLAYERS}
online-mode=true
enable-status=true
allow-flight=false
initial-disabled-packs=
broadcast-rcon-to-ops=true
view-distance=10
server-ip=
resource-pack-prompt=
allow-nether=true
server-port=25565
enable-rcon=true
rcon.password=${RCON_PASSWORD}
rcon.port=25575
sync-chunk-writes=true
op-permission-level=4
prevent-proxy-connections=false
hide-online-players=false
resource-pack=
entity-broadcast-range-percentage=100
simulation-distance=10
player-idle-timeout=0
force-gamemode=false
rate-limit=0
hardcore=false
white-list=false
broadcast-console-to-ops=true
spawn-npcs=true
spawn-animals=true
function-permission-level=2
initial-enabled-packs=vanilla
level-type=minecraft\:normal
text-filtering-config=
spawn-monsters=true
enforce-whitelist=false
spawn-protection=16
resource-pack-sha1=
max-world-size=29999984
EOF

cat << EOF > /etc/sudoers.d/minecraft
minecraft ALL=NOPASSWD:/usr/bin/systemctl stop minecraft,/usr/bin/systemctl start minecraft
EOF


# Backup script
cat << EOF > /usr/local/bin/minecraft-backup
#!/bin/bash
set -e -o pipefail

export MCRCON_PASS=$(cat /opt/minecraft/.config/mcrcon.pw)

ARCHIVE=\$(hostname).tgz
S3_URL=s3://${BACKUP_BUCKET}/worlds/\$ARCHIVE

echo "Backing up minecraft world data"

# See https://github.com/boto/boto3/issues/4398
export AWS_RESPONSE_CHECKSUM_VALIDATION=WHEN_REQUIRED
export AWS_REQUEST_CHECKSUM_CALCULATION=WHEN_REQUIRED

/opt/minecraft/tools/mcrcon/mcrcon "save-all flush"
tar cvzf \$ARCHIVE world

echo "Uploading world data to \$S3_URL"
aws s3 cp \$ARCHIVE \$S3_URL
rm \$ARCHIVE

echo "Backup complete"
EOF
chmod +x /usr/local/bin/minecraft-backup


# Restore script
cat << EOF > /usr/local/bin/minecraft-restore
#!/bin/bash

set -e -o pipefail

ARCHIVE=\$(hostname).tgz
S3_URL=s3://${BACKUP_BUCKET}/worlds/\$ARCHIVE

echo "Trying to restore minecraft world from \$S3_URL"
aws s3 cp \$S3_URL \$ARCHIVE

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

# Set ownership
chown -R minecraft:minecraft /opt/minecraft/server

# Start minecraft
>&2 echo "Starting minecraft"

systemctl daemon-reload
systemctl enable minecraft --now
