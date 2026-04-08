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

    tls = {
      source  = "hashicorp/tls"
      version = "=4.0.6"
    }
  }
}

resource "tls_private_key" "spacelift_api" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_private_key" "admin_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "random_string" "worker_pool_id" {
  length = 26
  number = true
  # Spacelift worker pool IDs use uppercase + digits, excluding I, L, O, U
  special          = true
  override_special = "ABCDEFGHJKMNPQRSTVWXYZ"
  lower            = false
  upper            = false
}

provider "azurerm" {
  features {}
  resource_provider_registrations = "none"
}

module "azure-worker" {
  source = "../../"

  admin_username   = var.admin_username
  admin_public_key = base64encode(tls_private_key.admin_ssh.public_key_openssh)

  configuration = <<-EOT
    export SPACELIFT_TOKEN="<token-here>"
    export SPACELIFT_POOL_PRIVATE_KEY="<private-key-here>"
  EOT

  resource_group = azurerm_resource_group.this
  subnet_id      = azurerm_subnet.worker.id

  identity_type = "SystemAssigned"

  worker_pool_id = random_string.worker_pool_id.id
  name_prefix    = "sp5ft-autoscaler"
  tags           = local.tags

  autoscaling_configuration = {
    max_create    = 2
    max_terminate = 1
    scale = {
      min = 1
      max = 5
    }
  }

  spacelift_api_credentials = {
    api_key_id       = "placeholder-api-key-id"
    api_key_secret   = "placholder-api-key-secret"
    api_key_endpoint = "https://spacelift-solutions.app.spacelift.io/graphql"
  }
}
