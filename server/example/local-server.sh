#!/bin/bash

# Helper script to run a local VM with libvirt and qemu to test the cloud-init scripts needed to set up a minecraft server.
#
# Prerequisites:
# - On Fedora: `sudo dnf install libvirt qemu-kvm virt-install genisoimage terraform`
# - Make sure libvirt is using qemu:///system
# - Add your user to the libvirt group: `sudo usermod -aG libvirt $USER`
# - Home directory should be world-readable for qemu to access the disk images

set -e -o pipefail

OS_VARIANT=ubuntujammy
IMG_ARCH="amd64"
IMG_PATH="../../packer/output/qemu-ubuntu/ubuntu-jammy.img"

NAME=minecraft-server
VMDIR=.vms/$NAME

if [[ ! -f dev.tfvars ]]; then
  >&2 echo "Please create a file called 'dev.tfvars' with the following contents:"
  >&2 echo "gcloud_rw_api_key=..."
  >&2 echo "gcloud_hosted_logs_id=..."
  >&2 echo "gcloud_hosted_metrics_id=..."
  >&2 echo "bucket_name=..."
  >&2 echo "s3_endpoint=..."
  exit 1
fi

create_server() {
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
  mkdir -p $VMDIR

  echo "instance-id: $NAME" > $VMDIR/meta-data
  echo "local-hostname: $NAME" >> $VMDIR/meta-data
  
  # Use terraform to generate the same cloud-init config as a live server would use
  terraform apply -auto-approve -var-file dev.tfvars && terraform output -raw cloud_config | base64 -d > $VMDIR/user-data

  # Generate ISO image for cloudinit
  genisoimage -output $VMDIR/cidata.iso -V cidata -r -J $VMDIR/user-data $VMDIR/meta-data

  # Generate file system from base image
  local backing_file=$(realpath $IMG_PATH)
  qemu-img create -b $backing_file -f qcow2 -F qcow2 $VMDIR/$NAME.img 10G

  # Virt-install
  virt-install \
      --name $NAME \
      --ram 2048 \
      --vcpus 2 \
      --import \
      --disk path=$VMDIR/$NAME.img,format=qcow2 \
      --disk path=$VMDIR/cidata.iso,device=cdrom \
      --os-variant=$OS_VARIANT \
      --memorybacking access.mode=shared \
      --noautoconsole
}

destroy_server() {
  virsh destroy $NAME || true
  virsh undefine $NAME --nvram || true
  rm -rf $VMDIR
}

get_login() {

  local max=10
  local cmd
  local ip_addr
  local mac_addr

  for ((i=1; i<=$max; i++)); do
    mac_addr=$(virsh dumpxml $NAME | grep "mac address" | sed "s/.*'\(.*\)'.*/\1/")

    set +e
    ip_addr=$(arp -n | grep "$mac_addr" | awk '{print $1}')
    set -e

    if [[ ! -z "$ip_addr" ]]; then
      ssh-add -D
      terraform output -raw private_key_pem | ssh-add -
      cmd="ssh -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" debian@$ip_addr"
      $cmd
      exit 0
    fi

    sleep 1s
  done

  >&2 echo "Failed to get IP for '$NAME' after ${max}s, is the VM running?"
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
