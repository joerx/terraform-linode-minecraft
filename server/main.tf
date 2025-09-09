locals {
  label       = "${var.stage}-${var.prefix}-${var.name}-${random_string.s.result}"
  short_label = "${var.stage}-${var.prefix}-${substr(var.name, 0, 21)}-${random_string.s.result}"
  hostname    = "${var.name}-${random_string.s.result}"
  tags        = ["service:${var.service}", "stage:${var.stage}", "name:${var.name}"]
  public_ip   = tolist(linode_instance.mc.ipv4)[0]
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "random_string" "s" {
  length  = 3
  special = false
  upper   = false
}

resource "random_password" "root_pw" {
  length = 20
}

resource "linode_firewall" "fw" {
  label = local.short_label
  tags  = local.tags

  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"

  inbound {
    label    = "minecraft"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = local.minecraft_port
    ipv4     = var.ingress
  }

  inbound {
    label    = "ssh"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = local.ssh_port
    ipv4     = var.ingress
  }
}

resource "linode_firewall_device" "d" {
  firewall_id = linode_firewall.fw.id
  entity_id   = linode_instance.mc.id
}

data "cloudinit_config" "init" {
  gzip          = false
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    filename     = "cloud-config.yaml"
    content = templatefile("${path.module}/init/cloud-init.yaml", {
      HOSTNAME               = local.label
      MINECRAFT_DOWNLOAD_URL = local.minecraft_download_urls[var.minecraft_version]
      OSS_ACCESS_KEY_ID      = linode_object_storage_key.k.access_key
      OSS_SECRET_ACCESS_KEY  = linode_object_storage_key.k.secret_key
      OSS_ENDPOINT           = var.backup.endpoint
      LEVEL_SEED             = var.level_seed == null ? "" : var.level_seed
      LEVEL_NAME             = "world"
      GAME_MODE              = var.game_mode
      DIFFICULTY             = var.difficulty
      REGION                 = var.region
      BACKUP_BUCKET          = var.backup.bucket
      SSH_PUBLIC_KEY         = chomp(tls_private_key.ssh_key.public_key_openssh)
    })
  }

  part {
    content_type = "text/x-shellscript"
    filename     = "setup-minecraft.sh"
    content      = file("${path.module}/init/setup-minecraft.sh")
  }
}

resource "linode_instance" "mc" {
  label           = local.label
  tags            = local.tags
  image           = var.image
  region          = var.region
  type            = var.instance_type
  root_pass       = random_password.root_pw.result
  authorized_keys = [chomp(tls_private_key.ssh_key.public_key_openssh)]

  metadata {
    user_data = data.cloudinit_config.init.rendered
  }
}

resource "linode_domain_record" "n" {
  domain_id   = var.domain_id
  name        = local.hostname
  target      = local.public_ip
  record_type = "A"
}

resource "linode_object_storage_key" "k" {
  label = local.label

  bucket_access {
    bucket_name = var.backup.bucket
    region      = var.region
    permissions = "read_write"
  }
}
