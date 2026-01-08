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

variable "vmss_instances" {
  type        = number
  description = "The number of VM instances to create."
  default     = 2
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

variable "autoscaling_enabled" {
  type        = bool
  description = "Whether to enable autoscaling for the worker pool using an Azure Function."
  default     = false
}

variable "autoscaling_configuration" {
  type = object({
    # Scheduling
    schedule_expression = optional(string, "0 */5 * * * *") # Every 5 minutes (Azure cron format: second minute hour day month weekday)

    # Scaling limits
    max_create       = optional(number, 1) # Maximum instances to create per run
    max_terminate    = optional(number, 1) # Maximum instances to terminate per run
    scale_down_delay = optional(number, 0) # Minutes a worker must be registered before eligible for termination

    # Capacity sanity check
    capacity_sanity_check = optional(number, 10) # Maximum capacity to prevent runaway scaling

    # Function timeout
    timeout = optional(number, 300) # Function timeout in seconds

    # Key Vault configuration
    key_vault_id = optional(string, null) # Existing Key Vault ID to use (if null, creates new one)

    # Binary source configuration
    binary_source = optional(string, "local") # Source of autoscaler binary: "local" or "download"

    # Download configuration (for future use)
    binary_download_url = optional(string, null)     # URL to download autoscaler binary from
    binary_version      = optional(string, null)     # Version of binary to download
    binary_architecture = optional(string, "x86_64") # Architecture: x86_64 or arm64
  })
  description = <<-EOT
    Configuration for the autoscaler Azure Function using the company-approved bootstrap binary.

    The binary auto-detects Azure VMSS based on the resource ID format and uses managed identity for authentication.

    Binary source options:
    - "local": Use the committed bootstrap binary (default, for testing)
    - "download": Download from URL (future implementation, similar to AWS module)

    Only used when autoscaling_enabled is true.
  EOT
  default = {
    schedule_expression   = "0 */5 * * * *"
    max_create            = 1
    max_terminate         = 1
    scale_down_delay      = 0
    capacity_sanity_check = 10
    timeout               = 300
    key_vault_id          = null
    binary_source         = "local"
    binary_download_url   = null
    binary_version        = null
    binary_architecture   = "x86_64"
  }

  validation {
    condition     = var.autoscaling_configuration.binary_source == "local" || var.autoscaling_configuration.binary_source == "download"
    error_message = "binary_source must be either 'local' or 'download'."
  }

  validation {
    condition     = var.autoscaling_configuration.binary_source != "download" || var.autoscaling_configuration.binary_download_url != null
    error_message = "binary_download_url must be provided when binary_source is 'download'."
  }

  validation {
    condition     = contains(["x86_64", "arm64"], var.autoscaling_configuration.binary_architecture)
    error_message = "binary_architecture must be either 'x86_64' or 'arm64'."
  }
}

variable "spacelift_api_key_id" {
  type        = string
  description = "Spacelift API key ID for the autoscaler. Required when autoscaling_enabled is true."
  default     = null
  sensitive   = true
}

variable "spacelift_api_key_secret" {
  type        = string
  description = "Spacelift API key secret for the autoscaler. Required when autoscaling_enabled is true."
  default     = null
  sensitive   = true
}

variable "spacelift_api_endpoint" {
  type        = string
  description = "Spacelift API endpoint for the autoscaler."
  default     = "https://spacelift.io"
}

variable "autoscaler_subnet_id" {
  type        = string
  description = "The subnet ID for the autoscaler Azure Function. If not provided, defaults to the worker pool subnet."
  default     = null
}

locals {
  namespace = "${var.name_prefix}-${var.worker_pool_id}"
}
