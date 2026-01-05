variable "worker_pool_id" {
  type        = string
  description = "The ID of the Spacelift worker pool"
}

variable "worker_pool_config" {
  type        = string
  description = "The worker pool configuration token from Spacelift"
  sensitive   = true
}

variable "worker_pool_private_key" {
  type        = string
  description = "The private key for the worker pool"
  sensitive   = true
}

variable "admin_password" {
  type        = string
  description = "Admin password for the VMSS instances"
  sensitive   = true
}

variable "admin_public_key" {
  type        = string
  description = "Base64 encoded SSH public key for the VMSS instances"
  sensitive   = true
}

variable "spacelift_api_key_id" {
  type        = string
  description = "Spacelift API key ID for the autoscaler"
  sensitive   = true
}

variable "spacelift_api_key_secret" {
  type        = string
  description = "Spacelift API key secret for the autoscaler"
  sensitive   = true
}
