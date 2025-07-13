mock_provider "linode" {}

mock_provider "random" {
  mock_resource "random_string" {
    defaults = {
      result = "abc"
    }
  }
}

variables {
  stage = "tst"
}

run "set_stackscript_label" {
  assert {
    condition     = linode_stackscript.s.label == "tst-minecraft-server-debian-abc"
    error_message = "incorrect label for StackScript"
  }
}

run "supports_debian11" {
  assert {
    condition     = contains(linode_stackscript.s.images, "linode/debian11")
    error_message = "StackScript does not support Debian 11"
  }
}

run "supports_ubuntu22_04" {
  assert {
    condition     = contains(linode_stackscript.s.images, "linode/ubuntu20.04")
    error_message = "StackScript does not support Ubuntu 22.04"
  }
}
