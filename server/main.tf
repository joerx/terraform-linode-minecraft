locals {
  label       = "${var.stage}-${var.prefix}-${var.name}-${random_string.s.result}"
  short_label = "${var.stage}-${var.prefix}-${substr(var.name, 0, 21)}-${random_string.s.result}"
  hostname    = "${var.name}-${random_string.s.result}"
  tags        = ["service:${var.service}", "stage:${var.stage}", "name:${var.name}"]
  public_ip   = var.enabled ? tolist(linode_instance.mc[0].ipv4)[0] : null

  mc_settings = {
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
    SSH_USER               = var.ssh_user
    RCON_PASSWORD          = random_password.rcon_pw.result
    RCON_VERSION           = "0.7.2"
    MAX_PLAYERS            = 20
    BACKUP_SCHEDULE        = var.backup_schedule
  }
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

resource "random_password" "rcon_pw" {
  length  = 20
  special = false
}

resource "linode_firewall" "fw" {
  count = var.enabled ? 1 : 0
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
  count       = var.enabled ? 1 : 0
  firewall_id = linode_firewall.fw[count.index].id
  entity_id   = linode_instance.mc[count.index].id
}

data "cloudinit_config" "init" {
  gzip          = false
  base64_encode = true

  dynamic "part" {
    for_each = var.gcloud != null ? [1] : []
    content {
      content_type = "text/cloud-config"
      filename     = "alloy.yaml"
      merge_type   = "list(append)+dict(no_replace,recurse_list)+str()"

      content = templatefile("${path.module}/init/alloy.yaml", {
        GCLOUD_SCRAPE_INTERVAL    = var.gcloud.scrape_interval
        GCLOUD_HOSTED_METRICS_URL = var.gcloud.hosted_metrics_url
        GCLOUD_HOSTED_METRICS_ID  = var.gcloud.hosted_metrics_id
        GCLOUD_HOSTED_LOGS_URL    = var.gcloud.hosted_logs_url
        GCLOUD_HOSTED_LOGS_ID     = var.gcloud.hosted_logs_id
        GCLOUD_RW_API_KEY         = var.gcloud.rw_api_key
      })
    }
  }

  part {
    content_type = "text/cloud-config"
    filename     = "cloud-config.yaml"
    merge_type   = "list(append)+dict(no_replace,recurse_list)+str()"

    content = templatefile("${path.module}/init/cloud-init.yaml", local.mc_settings)
  }

  part {
    content_type = "text/x-shellscript"
    filename     = "setup-minecraft.sh"
    content      = templatefile("${path.module}/init/setup-minecraft.sh", local.mc_settings)
  }
}

resource "linode_instance" "mc" {
  count     = var.enabled ? 1 : 0
  label     = local.label
  tags      = local.tags
  image     = var.image
  region    = var.region
  type      = var.instance_type
  root_pass = random_password.root_pw.result

  # authorized_users = ["warden"]
  authorized_keys = [chomp(tls_private_key.ssh_key.public_key_openssh)]

  metadata {
    user_data = data.cloudinit_config.init.rendered
  }
}

resource "linode_domain_record" "n" {
  count       = var.enabled ? 1 : 0
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
