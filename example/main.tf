locals {
  stage  = "dev"
  region = "eu-central"
  domain = "${local.region}.${local.stage}.cloudcraft.yodo.dev"
  name   = var.name != null ? var.name : random_pet.name[0].id
}

resource "random_pet" "name" {
  count     = var.name == null ? 1 : 0
  length    = 2
  separator = "-"
}

data "linode_domain" "d" {
  domain = local.domain
}

module "server" {
  source = "../server"

  enabled = var.enabled
  name    = local.name
  stage   = local.stage
  region  = local.region

  minecraft_version = "1.21.8"
  game_mode         = "creative"
  difficulty        = "peaceful"

  image   = var.image
  ingress = var.ingress

  domain_id = data.linode_domain.d.id

  backup = {
    bucket   = var.bucket_name
    endpoint = var.s3_endpoint
  }

  gcloud = {
    rw_api_key        = var.gcloud_rw_api_key
    hosted_logs_id    = var.gcloud_hosted_logs_id
    hosted_metrics_id = var.gcloud_hosted_metrics_id
  }
}
