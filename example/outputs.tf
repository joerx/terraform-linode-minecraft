output "label" {
  value = module.server.label
}

output "hostname" {
  value = module.server.hostname
}

output "public_ip" {
  value = module.server.public_ip
}

output "root_password" {
  sensitive = true
  value     = module.server.root_password
}

output "private_key_pem" {
  sensitive = true
  value     = module.server.private_key_pem
}

output "cloud_config" {
  value = module.server.cloud_config
}
