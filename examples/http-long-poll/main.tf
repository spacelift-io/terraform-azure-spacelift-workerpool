terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
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

  worker_pool_id = random_string.worker_pool_id.id
  name_prefix    = "sp5ft-http-long-poll"
  tags           = local.tags

  # HTTP long-polling is the default transport, so no worker communication
  # inputs are needed for the EU SaaS environment. The module exports:
  #
  #   SPACELIFT_WORKER_COMMS_PROTOCOL=poll
  #   SPACELIFT_WORKER_COMMS_URL=https://app.spacelift.io
  #
  # For US-region SaaS, uncomment the following line so the URL becomes
  # https://app.us.spacelift.io:
  #
  # domain_name = "us.spacelift.io"
  #
  # For self-hosted or FedRAMP Spacelift, set the server base URL explicitly:
  #
  # worker_comms_url = "https://spacelift.example.com"
  #
  # To temporarily remain on the deprecated MQTT transport during migration:
  #
  # worker_comms_protocol = "mqtt"
}
