variable "autoscaling_configuration" {
  type = object({
    version             = optional(string)
    architecture        = optional(string)
    schedule_expression = optional(string)
    max_create          = optional(number)
    max_terminate       = optional(number)
    timeout             = optional(number)
    scale_down_delay    = optional(number)
    scale = optional(object({
      min = number
      max = number
    }))
  })
}

variable "base_name" {
  type = string
}

variable "worker_pool_id" {
  type = string
}

variable "vmss_resource_id" {
  type        = string
  description = "The resource ID of the VMSS to scale."
}

variable "resource_group" {
  type = object({
    name     = string
    location = string
    id       = string
  })
  description = "The resource group containing the VMSS."
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources."
  default     = {}
}

variable "spacelift_api_credentials" {
  description = <<EOF
  Spacelift API credentials. This is used to authenticate the autoscaler with Spacelift.
  - api_key_id: (mandatory) The ID of the Spacelift API key.
  - api_key_secret: (mandatory) The secret corresponding to the Spacelift API key.
  - api_key_endpoint: (mandatory) The full URL of the Spacelift API endpoint. Example: https://mycorp.app.spacelift.io
  EOF
  sensitive   = true
  type = object({
    api_key_id       = string
    api_key_secret   = string
    api_key_endpoint = string
  })
}

variable "key_vault_id" {
  type        = string
  description = "Existing Key Vault ID to use. If null, a new Key Vault will be created."
  default     = null
}

variable "subnet_id" {
  type        = string
  description = "The subnet ID where the VMSS is deployed. Required for network join permissions during scaling."
}
