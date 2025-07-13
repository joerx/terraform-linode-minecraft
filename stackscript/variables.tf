variable "stage" {
  description = "Deployment stage the script is for"
}

variable "service" {
  description = "Service label"
  default     = "minecraft-server"
}

variable "is_public" {
  description = "Whether this script is publically available or not"
  default     = false
}
