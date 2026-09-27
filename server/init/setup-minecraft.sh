#!/bin/bash

set -e -o pipefail

# Load environment variables from defaults
test -f /etc/default/minecraft && echo "loading defaults from /etc/default/minecraft" && source /etc/default/minecraft

# AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install

# Download mcrcon
>&2 echo "Downloading mcrcon version ${RCON_VERSION}"
mkdir -p /opt/minecraft/tools/mcrcon
cd /opt/minecraft/tools/mcrcon
wget -nv https://github.com/Tiiffi/mcrcon/releases/download/v${RCON_VERSION}/mcrcon-${RCON_VERSION}-linux-x86-64.tar.gz
tar xzf mcrcon-${RCON_VERSION}-linux-x86-64.tar.gz
rm mcrcon-${RCON_VERSION}-linux-x86-64.tar.gz

# Download minecraft
mkdir -p /opt/minecraft/server && chown minecraft:minecraft /opt/minecraft/server
cd /opt/minecraft/server

>&2 echo "Download from ${MINECRAFT_DOWNLOAD_URL}"
wget -nv "${MINECRAFT_DOWNLOAD_URL}"
>&2 echo "Download complete"

# Basic configuration
echo "eula=true" > /opt/minecraft/server/eula.txt

# Set ownership
chown -R minecraft:minecraft /opt/minecraft/server

cat <<'EOF' > /etc/systemd/system/minecraft.service
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
  EnvironmentFile=/etc/default/minecraft
  ExecStart=/usr/bin/java -Xmx1024M -Xms1024M -jar server.jar nogui
  ExecStop=/opt/minecraft/tools/mcrcon/mcrcon -H 127.0.0.1 -P 25575 -p $RCON_PASSWORD stop

  [Install]
  WantedBy=multi-user.target
EOF

# If MINECRAFT_WORLD_URL is set and the backup already exists, download and
# extract it. The URL is bound to the Terraform workspace rather than the
# instance, so on first boot no backup may exist yet - in that case skip the
# restore and let the scheduled backup job perform a lazy init.
if [[ ! -z "$MINECRAFT_WORLD_URL" ]]; then
  if su minecraft -c "aws s3 ls '${MINECRAFT_WORLD_URL}'" > /dev/null 2>&1; then
    >&2 echo "Restoring world state from '$MINECRAFT_WORLD_URL'"
    ARCHIVE=$(basename "$MINECRAFT_WORLD_URL")
    su minecraft -c "aws s3 cp ${MINECRAFT_WORLD_URL} /opt/minecraft/server/$ARCHIVE"
    su minecraft -c "tar xzf /opt/minecraft/server/$ARCHIVE -C /opt/minecraft/server"
  else
    >&2 echo "No existing world state found at '$MINECRAFT_WORLD_URL', skipping restore"
  fi
fi

# Start minecraft
>&2 echo "Starting minecraft"

systemctl daemon-reload
systemctl enable minecraft --now
