packer {
  required_plugins {
    qemu = {
      version = ">= 1.1.3"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

variable "ubuntu_version" {
  type        = string
  default     = "jammy"
  description = "Ubuntu codename version (i.e. 20.04 is focal and 22.04 is jammy)"
}

source "qemu" "ubuntu" {
  accelerator      = "kvm"
  output_directory = "output/qemu-ubuntu"
  vm_name          = "ubuntu-${var.ubuntu_version}.img"

  iso_checksum = "file:https://cloud-images.ubuntu.com/${var.ubuntu_version}/current/SHA256SUMS"
  iso_url      = "https://cloud-images.ubuntu.com/${var.ubuntu_version}/current/${var.ubuntu_version}-server-cloudimg-amd64.img"

  # iso_url          = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2"
  # iso_checksum     = "sha512:2d63144148d3e1c1cec456c201965c1f3345daeecf8ca708e6aeaadbae352a1aa20ca5e3de600aac514bb9b98c940ea0c770cada58c3e7ebcf4e2bf85c57ec65"

  disk_compression = true
  disk_image       = true
  disk_size        = "10G" # Machines created from this image will need at least a 10G disk

  ssh_username         = "ubuntu"
  ssh_private_key_file = "~/.ssh/id_ed25519"
  ssh_timeout          = "20m"

  cd_files = ["./init/*"]
  cd_label = "cidata"

  headless         = true
  boot_wait        = "10s"
  shutdown_command = "sudo -S shutdown -P now"

  qemuargs = [
    ["-m", "2048M"],
    ["-smp", "2"],
    ["-serial", "mon:stdio"],
  ]
}

build {
  name = "ubuntu"

  sources = [
    "source.qemu.ubuntu",
  ]

  provisioner "shell" {
    execute_command = "sudo env {{ .Vars }} {{ .Path }}"

    environment_vars = [
      "MESSAGE=hello world",
    ]

    scripts = [
      "./scripts/setup.sh",
      "./scripts/cleanup.sh",
    ]
  }
}
