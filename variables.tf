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
  })
  description = "The resource group to deploy the scale set to."
}

variable "source_image_id" {
  type        = string
  description = "The VM image to use. Either source_image_id, or a combination of source_image_publisher, source_image_offer, source_image_sku, and source_image_version must be specified."
  default     = null
}

variable "source_image_publisher" {
  type        = string
  description = "The image publisher to use. Either source_image_id, or a combination of source_image_publisher, source_image_offer, source_image_sku, and source_image_version must be specified."
  default     = "spaceliftinc1625499025476"
}

variable "source_image_offer" {
  type        = string
  description = "The image offer to use. Either source_image_id, or a combination of source_image_publisher, source_image_offer, source_image_sku, and source_image_version must be specified."
  default     = "spacelift_worker"
}

variable "source_image_sku" {
  type        = string
  description = "The image SKU to use. Either source_image_id, or a combination of source_image_publisher, source_image_offer, source_image_sku, and source_image_version must be specified."
  default     = "ubuntu_20_04"
}

variable "source_image_version" {
  type        = string
  description = "The image version to use. Either source_image_id, or a combination of source_image_publisher, source_image_offer, source_image_sku, and source_image_version must be specified."
  default     = "latest"
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

locals {
  namespace = "${var.name_prefix}-${var.worker_pool_id}"
}
