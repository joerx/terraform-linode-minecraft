mock_provider "linode" {
  mock_resource "linode_firewall" {
    defaults = {
      id = "123"
    }
  }

  mock_resource "linode_instance" {
    defaults = {
      id   = "123"
      ipv4 = ["1.2.3.4"]
    }
  }

  mock_resource "linode_object_storage_key" {
    defaults = {
      access_key = "ossAccessKeyId"
      secret_key = "ossSecretKey"
    }
  }
}

variables {
  domain_id         = "1234567890"
  stackscript_id    = "0987654321"
  minecraft_version = "1.19.3"
  game_mode         = "creative"
  difficulty        = "peaceful"
  level_seed        = "124014738"
  stage             = "sbx"
  ingress           = ["1.2.3.4/32"]
  region            = "eu-central"

  backup = {
    bucket = "a-bucket"
  }
}

run "setup" {
  module {
    source = "./tests/setup"
  }
}

run "download_url_for_1_19_3" {
  variables {
    name = run.setup.random_pet
  }

  assert {
    condition     = linode_instance.mc.stackscript_data["MINECRAFT_DOWNLOAD_URL"] == "https://piston-data.mojang.com/v1/objects/c9df48efed58511cdd0213c56b9013a7b5c9ac1f/server.jar"
    error_message = "incorrect download URL for Minecraft version 1.19.3"
  }
}

run "download_url_for_1_21_7" {
  variables {
    name              = run.setup.random_pet
    minecraft_version = "1.21.7"
  }

  assert {
    condition     = linode_instance.mc.stackscript_data["MINECRAFT_DOWNLOAD_URL"] == "https://piston-data.mojang.com/v1/objects/05e4b48fbc01f0385adb74bcff9751d34552486c/server.jar"
    error_message = "incorrect download URL for Minecraft version 1.21.7"
  }
}

run "firewall_inbound_rules" {
  variables {
    name = run.setup.random_pet
  }

  assert {
    condition     = length(linode_firewall.fw.inbound) == 2
    error_message = "expected 2 inbound rules in the firewall"
  }

  assert {
    condition     = linode_firewall.fw.inbound[0].ports == "25565"
    error_message = "first inbound rule should be for Minecraft"
  }

  assert {
    condition     = linode_firewall.fw.inbound[0].ipv4 == var.ingress
    error_message = "second inbound rule should allow ingress IPs"
  }

  assert {
    condition     = linode_firewall.fw.inbound[1].ports == "22"
    error_message = "second inbound rule should be for SSH"
  }

  assert {
    condition     = linode_firewall.fw.inbound[1].ipv4 == var.ingress
    error_message = "second inbound rule should allow ingress IPs"
  }
}

run "linode_instance_created" {
  variables {
    name = run.setup.random_pet
  }

  assert {
    condition     = linode_instance.mc != null
    error_message = "expected Linode instance to be created"
  }

  assert {
    condition     = startswith(linode_instance.mc.label, "${var.stage}-mc-${var.name}")
    error_message = "instance label does not match expected format"
  }

  assert {
    condition     = linode_instance.mc.type == var.instance_type
    error_message = "instance type does not match expected value"
  }

  assert {
    condition     = linode_instance.mc.region == var.region
    error_message = "instance region does not match expected value"
  }

  assert {
    condition     = linode_instance.mc.root_pass == output.root_password
    error_message = "instance root password does not match expected value"
  }
}

run "linode_instance_with_long_label" {
  command = plan

  variables {
    name = "${run.setup.random_pet}-${run.setup.random_pet}-${run.setup.random_pet}-${run.setup.random_pet}-${run.setup.random_pet}"
  }

  expect_failures = [
    var.name,
  ]
}

run "linode_instance_with_long_prefix" {
  command = plan

  variables {
    name   = run.setup.random_pet
    prefix = "abc"
  }

  expect_failures = [
    var.prefix,
  ]
}

run "oss_credentials_created" {
  variables {
    name = run.setup.random_pet
  }

  assert {
    condition     = anytrue([for b in linode_object_storage_key.k.bucket_access : b.bucket_name == var.backup.bucket])
    error_message = "expected limited object storage key to be created"
  }

  assert {
    condition     = linode_instance.mc.stackscript_data["OSS_ACCESS_KEY_ID"] == linode_object_storage_key.k.access_key
    error_message = "OSS access key id not set correctly in stackscript data"
  }

  assert {
    condition     = linode_instance.mc.stackscript_data["OSS_SECRET_ACCESS_KEY"] == linode_object_storage_key.k.secret_key
    error_message = "OSS secret access key not set correctly in stackscript data"
  }
}

run "oss_endpoint_set" {
  variables {
    name = run.setup.random_pet
  }

  assert {
    condition     = linode_instance.mc.stackscript_data["OSS_ENDPOINT"] == "https://eu-central-1.linodeobjects.com"
    error_message = "OSS endpoint not set correctly in stackscript data"
  }
}

run "invalid_region" {
  command = plan

  variables {
    name   = run.setup.random_pet
    region = "invalid-region"
  }

  expect_failures = [
    var.region,
  ]
}
