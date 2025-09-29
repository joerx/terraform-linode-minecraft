terraform {
  # See https://github.com/hashicorp/terraform/issues/36704
  required_version = ">= 1.0, < 1.11.2"

  required_providers {
    linode = {
      source = "linode/linode"
    }
  }
}
