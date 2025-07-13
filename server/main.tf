locals {
  label = "${var.stage}-${var.service}"
  tags  = ["service:${var.service}", "stage:${var.stage}"]

  minecraft_download_urls = {
    "1.19.3" = "https://piston-data.mojang.com/v1/objects/c9df48efed58511cdd0213c56b9013a7b5c9ac1f/server.jar"
    "1.19.4" = "https://piston-data.mojang.com/v1/objects/8f3112a1049751cc472ec13e397eade5336ca7ae/server.jar"
    "1.21.7" = "https://piston-data.mojang.com/v1/objects/05e4b48fbc01f0385adb74bcff9751d34552486c/server.jar"
  }

  minecraft_port = "25565"
  ssh_port       = "22"
  public_ip      = tolist(linode_instance.mc.ipv4)[0]
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "random_password" "root_pw" {
  length = 20
}

resource "linode_firewall" "fw" {
  label = local.label
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

resource "linode_instance" "mc" {
  label           = local.label
  tags            = local.tags
  image           = var.image
  region          = var.region
  type            = var.instance_type
  root_pass       = random_password.root_pw.result
  authorized_keys = [chomp(tls_private_key.ssh_key.public_key_openssh)]

  stackscript_id = var.stackscript_id
  stackscript_data = {
    "HOSTNAME"               = local.label
    "GAME_MODE"              = var.game_mode
    "LEVEL_SEED"             = var.level_seed
    "DIFFICULTY"             = var.difficulty
    "MINECRAFT_DOWNLOAD_URL" = local.minecraft_download_urls[var.minecraft_version]
    "OSS_BUCKET"             = var.backup.bucket
    "OSS_ACCESS_KEY_ID"      = var.backup.access_key_id
    "OSS_SECRET_ACCESS_KEY"  = var.backup.secret_key
    "OSS_ENDPOINT"           = var.backup.endpoint
  }
}

resource "linode_domain_record" "n" {
  domain_id   = var.domain_id
  name        = local.label
  target      = local.public_ip
  record_type = "A"
}
