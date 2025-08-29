terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.42.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "=3.1.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
  resource_provider_registrations = "none"
}

module "azure-worker" {
  source = "../../"

  admin_username   = var.admin_username
  admin_public_key = var.admin_public_key

  configuration = <<-EOT
    export SPACELIFT_TOKEN=${var.worker_pool_config}
    export SPACELIFT_POOL_PRIVATE_KEY=${var.worker_pool_private_key}
  EOT

  resource_group = azurerm_resource_group.this
  subnet_id      = azurerm_subnet.worker.id

  identity_type = "SystemAssigned"

  worker_pool_id = var.worker_pool_id
  name_prefix    = "sp5ft-system-identity"
  tags           = local.tags
}
