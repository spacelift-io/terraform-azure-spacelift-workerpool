# Key Vault and Secret resources for the autoscaler
# Stores the Spacelift API key secret securely

# Data source to get current Azure client config
data "azurerm_client_config" "current" {}

# Key Vault for storing secrets (or use existing one if provided)
resource "azurerm_key_vault" "autoscaler" {
  count = var.autoscaling_enabled && var.autoscaling_configuration.key_vault_id == null ? 1 : 0

  name                = "${local.namespace}-kv"
  resource_group_name = var.resource_group.name
  location            = var.resource_group.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # Enable purge protection to prevent accidental deletion
  purge_protection_enabled = true

  # Soft delete retention
  soft_delete_retention_days = 7

  # Network ACLs - adjust as needed for your environment
  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }

  tags = merge(var.tags, {
    WorkerPoolID = var.worker_pool_id
    Component    = "Autoscaler"
  })
}

# Data source to reference existing Key Vault if provided
data "azurerm_key_vault" "existing" {
  count = var.autoscaling_enabled && var.autoscaling_configuration.key_vault_id != null ? 1 : 0

  name                = split("/", var.autoscaling_configuration.key_vault_id)[8]
  resource_group_name = split("/", var.autoscaling_configuration.key_vault_id)[4]
}

# Local to determine which Key Vault to use
locals {
  key_vault_id   = var.autoscaling_enabled ? (var.autoscaling_configuration.key_vault_id != null ? data.azurerm_key_vault.existing[0].id : azurerm_key_vault.autoscaler[0].id) : null
  key_vault_name = var.autoscaling_enabled ? (var.autoscaling_configuration.key_vault_id != null ? data.azurerm_key_vault.existing[0].name : azurerm_key_vault.autoscaler[0].name) : null
}

# Secret for Spacelift API key
resource "azurerm_key_vault_secret" "spacelift_api_key" {
  count = var.autoscaling_enabled ? 1 : 0

  name         = "spacelift-api-key-secret"
  value        = var.spacelift_api_key_secret
  key_vault_id = local.key_vault_id

  content_type = "text/plain"

  tags = merge(var.tags, {
    WorkerPoolID = var.worker_pool_id
    Component    = "Autoscaler"
  })

  depends_on = [
    azurerm_key_vault.autoscaler
  ]
}

# Grant Key Vault access to the deploying user/service principal
# This is needed to create secrets
resource "azurerm_key_vault_access_policy" "deployer" {
  count = var.autoscaling_enabled && var.autoscaling_configuration.key_vault_id == null ? 1 : 0

  key_vault_id = azurerm_key_vault.autoscaler[0].id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete",
    "Purge",
    "Recover"
  ]
}

# Output the Key Vault secret URL for reference
output "autoscaler_key_vault_secret_url" {
  value       = var.autoscaling_enabled ? azurerm_key_vault_secret.spacelift_api_key[0].versionless_id : null
  description = "The URL of the Spacelift API key secret in Key Vault"
  sensitive   = true
}
