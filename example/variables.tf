variable "gcloud_rw_api_key" {
  type        = string
  description = "Google Cloud Read/Write API Key for Alloy"
}

variable "gcloud_hosted_logs_id" {
  type        = string
  description = "Google Cloud Hosted Logs ID for Alloy"
}

variable "gcloud_hosted_metrics_id" {
  type        = string
  description = "Google Cloud Hosted Metrics ID for Alloy"
}

variable "bucket_name" {
  type        = string
  description = "Name of the backup bucket"
}

variable "s3_endpoint" {
  type        = string
  description = "S3 Endpoint for the backup bucket"
}

variable "enabled" {
  description = "If false, only configuration is generated but no resources are created"
  type        = bool
  default     = false
}

variable "ingress" {
  type        = list(string)
  description = "List of CIDR blocks to allow SSH access"
  default     = ["127.0.0.1/24"]
}

variable "name" {
  type        = string
  description = "Name of the server"
  default     = null
}

variable "image" {
  type        = string
  description = "Image to use for the instance"
}
