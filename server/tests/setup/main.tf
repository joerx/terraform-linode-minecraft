terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5.1"
    }
  }
}

resource "random_pet" "p" {}

output "random_pet" {
  value = random_pet.p.id
}
