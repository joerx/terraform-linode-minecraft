#!/bin/bash

# Helper script to run a local VM with libvirt and qemu to test the cloud-init scripts needed to set up a minecraft server.
# 
# Prerequisites:
# - On Fedora: `sudo dnf install libvirt qemu-kvm virt-install genisoimage cloud-utils-write-mime-multipart`
# - Make sure libvirt is using qemu:///system
# - Add your user to the libvirt group: `sudo usermod -aG libvirt $USER`
# - Home directory should be world-readable for qemu to access the disk images

set -e -o pipefail

OS_VARIANT=debian13

# IMG_ARCH=$(uname -m)
IMG_ARCH="amd64"
IMG_VARIANT=debian-13-generic
IMG_DOWNLOAD_URL="https://cloud.debian.org/images/cloud/trixie/latest/${IMG_VARIANT}-${IMG_ARCH}.qcow2"
IMG_DIR=$HOME/.local/share/images

IMG_NAME=$(basename $IMG_DOWNLOAD_URL)

NAME=minecraft-server
VMDIR=.vms/$NAME

BACKUP_BUCKET="dev-minecraft-backup-0ffl"
SSH_PUBLIC_KEY=$(cat ~/.ssh/id_ed25519.pub || cat ~/.ssh/id_rsa.pub)
MINECRAFT_DOWNLOAD_URL="https://piston-data.mojang.com/v1/objects/6bce4ef400e4efaa63a13d5e6f6b500be969ef81/server.jar" # 1.21.8
REGION=eu-central
OSS_ENDPOINT=eu-central-1.linodeobjects.com

if [[ ! -f .env ]]; then
  >&2 echo "Please create a .env file with the following contents:"
  >&2 echo "OSS_ACCESS_KEY_ID=..."
  >&2 echo "OSS_SECRET_ACCESS_KEY=..."
  exit 1
fi

. .env

if [[ -z "$OSS_ACCESS_KEY_ID" || -z "$OSS_SECRET_ACCESS_KEY" ]]; then
  >&2 echo "Please set OSS_ACCESS_KEY_ID and OSS_SECRET_ACCESS_KEY in .env"
  exit 1
fi

create_server() {
  # Download image if not already present
  if [[ ! -d $IMG_DIR ]]; then
    mkdir -p $IMG_DIR
  fi

  if [[ ! -f $IMG_DIR/$IMG_NAME ]]; then
    >&2 echo "Downloading base image from $IMG_DOWNLOAD_URL"
    curl -Lf $IMG_DOWNLOAD_URL -o images/$IMG_NAME
  else
    >&2 echo "Image already exists, skipping download"
  fi


  # Find users SSH key to add to authorized_keys later
  if [[ -f ~/.ssh/id_ed25519.pub ]]; then
    SSH_RSA=$(cat ~/.ssh/id_ed25519.pub)
  elif [[ -f ~/.ssh/id_rsa.pub ]]; then
    SSH_RSA=$(cat ~/.ssh/id_rsa.pub)
  else
    >&2 echo "No SSH key found, please generate one with ssh-keygen"
    exit 1
  fi


  # Generate meta-data and user-data files
  # NB: We need multi-part MIME to inject user scripts on top of the default one
  # See https://cloudinit.readthedocs.io/en/latest/explanation/format.html#helper-subcommand-to-generate-mime-messages
  mkdir -p $VMDIR

  echo "instance-id: $NAME" > $VMDIR/meta-data
  echo "local-hostname: $NAME" >> $VMDIR/meta-data

  cat init/cloud-init.yaml | \
    sed "s|\${SSH_PUBLIC_KEY}|$SSH_PUBLIC_KEY|g" | \
    sed "s|\${REGION}|$REGION|g" | \
    sed "s|\${HOSTNAME}|$NAME|g" | \
    sed "s|\${MINECRAFT_DOWNLOAD_URL}|$MINECRAFT_DOWNLOAD_URL|g" | \
    sed "s|\${MAX_PLAYERS}|20|g" | \
    sed "s|\${LEVEL_NAME}|world|g" | \
    sed "s|\${LEVEL_SEED}||g" | \
    sed "s|\${GAME_MODE}|creative|g" | \
    sed "s|\${DIFFICULTY}|peaceful|g" | \
    sed "s|\${BACKUP_BUCKET}|$BACKUP_BUCKET|g" | \
    sed "s|\${OSS_ENDPOINT}|$OSS_ENDPOINT|g" | \
    sed "s|\${OSS_ACCESS_KEY_ID}|$OSS_ACCESS_KEY_ID|g" | \
    sed "s|\${OSS_SECRET_ACCESS_KEY}|$OSS_SECRET_ACCESS_KEY|g" \
    > $VMDIR/cloud-init.yaml

  write-mime-multipart --output=$VMDIR/user-data \
    $VMDIR/cloud-init.yaml:text/cloud-config \
    init/setup-minecraft.sh:text/x-shellscript

  # Generate file system from base image
  qemu-img create -b $IMG_DIR/$IMG_NAME -f qcow2 -F qcow2 $VMDIR/$NAME.qcow2 10G

  # Generate ISO image for cloudinit
  genisoimage -output $VMDIR/cidata.iso -V cidata -r -J $VMDIR/user-data $VMDIR/meta-data

  # Virt-install
  virt-install \
      --name $NAME \
      --ram 2048 \
      --vcpus 2 \
      --import \
      --disk path=$VMDIR/$NAME.qcow2,format=qcow2 \
      --disk path=$VMDIR/cidata.iso,device=cdrom \
      --os-variant=$OS_VARIANT \
      --memorybacking access.mode=shared \
      --noautoconsole
      # --filesystem source=$PWD,target=code,accessmode=passthrough,driver.type=virtiofs \
}

destroy_server() {
  virsh destroy $NAME || true
  virsh undefine $NAME --nvram || true
  rm -rf $VMDIR
}

get_login() {
  virsh domifaddr $NAME
  # echo "ssh debian@<IP_ADDRESS>"
}


case "$1" in
  create)
    create_server
    ;;
  destroy)
    destroy_server
    ;;
  login)
    get_login
    ;;
  *)
    echo "Usage: $0 {create|destroy}"
    exit 1
    ;;
esac

# To log in:
# virsh domifaddr minecraft-server
# ssh debian@<IP_ADDRESS>
