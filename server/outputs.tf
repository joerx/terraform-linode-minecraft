output "label" {
  value = linode_instance.mc.label
}

output "hostname" {
  description = "Hostname part of the DNS record"
  value       = local.hostname
}

output "public_ip" {
  value = local.public_ip
}

output "root_password" {
  sensitive = true
  value     = random_password.root_pw.result
}

output "private_key_pem" {
  sensitive = true
  value     = tls_private_key.ssh_key.private_key_pem
}

output "minecraft_port" {
  value = local.minecraft_port
}

output "ssh_port" {
  value = local.ssh_port
}
