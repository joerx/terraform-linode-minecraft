terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5.1"
    }
  }
}

resource "random_pet" "p" {}

output "service_label" {
  value = random_pet.p.id
}
