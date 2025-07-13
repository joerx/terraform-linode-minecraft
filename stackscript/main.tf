locals {
  os_family = "debian"
  service   = var.service
  label     = "${var.stage}-${var.service}-${local.os_family}-${random_string.s.result}"
}

resource "random_string" "s" {
  length  = 3
  special = false
}

resource "linode_stackscript" "s" {
  label     = local.label
  is_public = var.is_public

  script = chomp(templatefile("${path.module}/script.sh", {
    server_properties = file("${path.module}/server.properties")
  }))

  description = <<-EOF
  StackScript to install Minecraft server on Debian-based operating systems.
  EOF

  # See https://api.linode.com/v4/images for a full list
  images = [
    "linode/debian11",
    "linode/ubuntu20.04",
    "linode/ubuntu22.04",
  ]
}
