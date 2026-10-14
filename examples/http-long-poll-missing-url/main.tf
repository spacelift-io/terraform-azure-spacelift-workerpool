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
  name_prefix    = "sp5ft-http-long-poll-missing-url"
  tags           = local.tags

  # NEGATIVE TEST: worker_comms_protocol defaults to "poll", which requires
  # worker_comms_url. It is deliberately omitted here so the plan must fail
  # with the module's precondition error.
}
