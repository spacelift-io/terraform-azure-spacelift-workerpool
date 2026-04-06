variable "admin_password" {
  type        = string
  default     = null
  description = "The admin password for the scale set. Either admin_password or admin_public_key must be set."
}

variable "admin_public_key" {
  type        = string
  description = "The base64 encoded public key. Either admin_public_key or admin_password must be set."
  default     = null
}

variable "admin_username" {
  type        = string
  description = "The admin username for the scale set."
  default     = "spacelift"
}

variable "application_security_group_ids" {
  type        = list(string)
  description = "Any Application Security Groups to tag the VM NICs with."
  default     = null
}

variable "configuration" {
  type        = string
  description = "Allows custom configuration to be performed as part of the startup script."
}

variable "domain_name" {
  type        = string
  description = "Top-level domain name to use for pulling the launcher binary."
  default     = "spacelift.io"
}

variable "identity_ids" {
  type        = list(string)
  description = "The list of user-assigned identities to associate with the VM instances."
  default     = null
}

variable "identity_type" {
  type        = string
  description = "The type of identity to associate with the VM instances."
  default     = null
}

variable "name_prefix" {
  type    = string
  default = "sp5ft"
}

variable "overprovision" {
  type        = bool
  description = "Indicates whether to allow Azure to overprovision the number of VM replicas when adding VMs."
  default     = true
}

variable "resource_group" {
  type = object({
    name     = string
    location = string
    id       = string
  })
  description = "The resource group to deploy the scale set to."
}

variable "source_image_id" {
  type        = string
  description = "The VM image to use. Either source_image_id, or a combination of source_image_publisher, source_image_offer, source_image_sku, and source_image_version must be specified."
  default     = "/communityGalleries/spacelift-40913cda-9bf9-4bcb-bf90-78fd83f30079/images/spacelift_worker_image/versions/latest"
}

variable "source_image_publisher" {
  type        = string
  description = "The image publisher to use. Either source_image_id, or a combination of source_image_publisher, source_image_offer, source_image_sku, and source_image_version must be specified."
  default     = null
}

variable "source_image_offer" {
  type        = string
  description = "The image offer to use. Either source_image_id, or a combination of source_image_publisher, source_image_offer, source_image_sku, and source_image_version must be specified."
  default     = null
}

variable "source_image_sku" {
  type        = string
  description = "The image SKU to use. Either source_image_id, or a combination of source_image_publisher, source_image_offer, source_image_sku, and source_image_version must be specified."
  default     = null
}

variable "source_image_version" {
  type        = string
  description = "The image version to use. Either source_image_id, or a combination of source_image_publisher, source_image_offer, source_image_sku, and source_image_version must be specified."
  default     = null
}

variable "subnet_id" {
  type        = string
  description = "The ID of the Azure subnet to place the VMs in."
}

variable "tags" {
  type        = map(string)
  description = "Any tags to add to the resources this module creates."
  default     = {}
}

variable "non_autoscaled_vmss_instances" {
  type        = number
  description = "The number of VM instances to create."
  default     = 2
}

variable "os_disk_storage_account_type" {
  type        = string
  description = "The storage account type for the OS disk. Standard_LRS (HDD) is being retired by Azure on September 8, 2028."
  default     = "StandardSSD_LRS"
  validation {
    condition     = contains(["Standard_LRS", "StandardSSD_LRS", "Premium_LRS", "StandardSSD_ZRS", "Premium_ZRS"], var.os_disk_storage_account_type)
    error_message = "The os_disk_storage_account_type must be one of: Standard_LRS, StandardSSD_LRS, Premium_LRS, StandardSSD_ZRS, Premium_ZRS."
  }
}

variable "vmss_sku" {
  type        = string
  description = "The VM SKU to use for the VMSS instances."
  default     = "Standard_B2S"
}

variable "worker_pool_id" {
  type        = string
  description = "The ID of the Spacelift worker pool."
}

variable "process_exit_behavior" {
  type        = string
  description = "The behavior to use when the Spacelift process exits"
  default     = "Reboot"
  validation {
    condition     = can(regex("^(Reboot|Shutdown|None)$", var.process_exit_behavior))
    error_message = "The process_exit_behavior value must be one of: [Reboot, Shutdown, None]."
  }
}

variable "perform_unattended_upgrade_on_boot" {
  type        = bool
  description = "Indicates whether unattended-upgrade should be run on startup to ensure the latest security updates are installed. Defaults to true."
  default     = true
}

variable "autoscaling_configuration" {
  description = <<EOF
  Configuration for the autoscaler Azure Function. If null, the autoscaler will not be deployed. Configuration options are:
  - version: (optional) Version of the autoscaler to deploy (e.g., "v2.2.0"). Defaults to "latest".
  - architecture: (optional) Instruction set architecture of the autoscaler. Can be "amd64" or "arm64". Defaults to "amd64".
  - schedule_expression: (optional) Azure Functions cron expression for autoscaler scheduling. Default: "0 */5 * * * *" (every 5 minutes).
  - max_create: (optional) Maximum number of instances the autoscaler can create in a single run. Default: 1.
  - max_terminate: (optional) Maximum number of instances the autoscaler can terminate in a single run. Default: 1.
  - timeout: (optional) Timeout in seconds for a single autoscaling run. Default: 300.
  - key_vault_id: (optional) Existing Key Vault ID to use for storing secrets. If null, a new Key Vault will be created.
  - scale_down_delay: (optional) Minutes a worker must be registered before eligible for termination. Default: 0.
  EOF

  type = object({
    version             = optional(string)
    architecture        = optional(string)
    schedule_expression = optional(string)
    max_create          = optional(number)
    max_terminate       = optional(number)
    timeout             = optional(number)
    key_vault_id        = optional(string)
    scale_down_delay    = optional(number)
    scale = optional(object({
      min = number
      max = number
    }))
  })
  default = null
}

variable "spacelift_api_credentials" {
  description = <<EOF
  Spacelift API credentials for the autoscaler. Required when autoscaling_configuration is provided.
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
  default = null
}

locals {
  namespace           = "${var.name_prefix}-${var.worker_pool_id}"
  autoscaling_enabled = var.autoscaling_configuration != null
}
