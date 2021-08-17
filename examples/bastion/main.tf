terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.68.0"
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
}

module "azure-worker" {
  source = "../../"

  admin_username   = var.admin_username
  admin_public_key = var.admin_public_key

  # This custom configuration block logs into Azure, downloads the worker pool credentials
  # from KeyVault, and then configures the environment variables the Spacelift worker will
  # read them from.
  configuration = <<-EOT
    az login --identity --allow-no-subscriptions

    echo "Downloading worker pool credentials from KeyVault" >> /var/log/spacelift/info.log
    az keyvault secret download --name "${azurerm_key_vault_secret.worker_pool_config.name}" \
      --vault-name "${azurerm_key_vault.this.name}" \
      --file "/tmp/worker-pool-config" 1>>/var/log/spacelift/info.log 2>>/var/log/spacelift/error.log

    az keyvault secret download --name "${azurerm_key_vault_secret.worker_pool_private_key.name}" \
      --vault-name "${azurerm_key_vault.this.name}" \
      --file "/tmp/worker-pool-private-key" 1>>/var/log/spacelift/info.log 2>>/var/log/spacelift/error.log

    export SPACELIFT_TOKEN=$(cat /tmp/worker-pool-config | base64 --decode)
    export SPACELIFT_POOL_PRIVATE_KEY=$(cat /tmp/worker-pool-private-key | base64 --decode)

    rm /tmp/worker-pool-config
    rm /tmp/worker-pool-private-key

    echo "Worker pool credentials configured" >> /var/log/spacelift/info.log
  EOT

  resource_group                 = azurerm_resource_group.this
  subnet_id                      = azurerm_subnet.worker.id
  application_security_group_ids = [azurerm_application_security_group.linux.id]

  identity_type = "UserAssigned"
  identity_ids  = [azurerm_user_assigned_identity.vmss.id]

  worker_pool_id = var.worker_pool_id
  name_prefix    = "sp5ft-bastion"
  tags           = local.tags
}
