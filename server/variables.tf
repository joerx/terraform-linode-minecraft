variable "stage" {
  description = "Deployment stage, for generating labels and tags"
  type        = string
}

variable "name" {
  description = "Unique name for the server instance, used in labels and tags"
  type        = string

  validation {
    condition     = length(var.name) <= 40
    error_message = "Name must be 40 characters or less"
  }
}

variable "service" {
  description = "Service name, for generating labels and tags"
  type        = string
  default     = "minecraft"
}

variable "prefix" {
  description = "Prefix to use for labels"
  type        = string
  default     = "mc"

  validation {
    condition     = length(var.prefix) <= 2
    error_message = "Prefix must be 2 characters or less"
  }
}

variable "ingress" {
  type = list(string)
}

variable "image" {
  description = "Machine image to use for the instance"
  type        = string
  default     = "linode/debian11"
}

variable "region" {
  description = "Region to deploy the instance to"
  type        = string
}

variable "instance_type" {
  description = "Size of the instance to create"
  type        = string
  default     = "g6-standard-1"
}

variable "domain_id" {
  description = "ID of a linode domain to create DNS records for this instance"
  type        = string
}

variable "minecraft_version" {
  description = "Version of Minecraft to use for default download URL"
  default     = "1.19.3"
}

variable "game_mode" {
  description = "Game mode for Minecraft server"
  default     = "survival"
}

variable "backup" {
  description = "Settings for world backup and restore"

  type = object({
    bucket   = string
    endpoint = string
  })
}

variable "enabled" {
  description = "If false, instance will be terminated"
  type        = bool
  default     = true
}

variable "difficulty" {
  description = "Game difficulty, valid values are 'peaceful', 'easy', 'normal' or 'hard'"
  type        = string
  default     = "easy"
}

variable "level_seed" {
  description = "Level seed"
  type        = string
  default     = null
}

variable "gcloud" {
  description = "Settings for Google Cloud hosted metrics and logs"
  default     = null

  type = object({
    hosted_metrics_id  = string
    hosted_logs_id     = string
    rw_api_key         = string
    scrape_interval    = optional(string, "60s")
    hosted_metrics_url = optional(string, "https://prometheus-prod-24-prod-eu-west-2.grafana.net/api/prom/push")
    hosted_logs_url    = optional(string, "https://logs-prod-012.grafana.net/loki/api/v1/push")
  })
}
