# KeyVault names need to be globally unique, so we'll just generate a random ID with a specified prefix.
resource "random_id" "keyvault" {
  byte_length = 9
  prefix      = "sp5ft"
}

resource "azurerm_key_vault" "this" {
  name                       = random_id.keyvault.hex
  location                   = azurerm_resource_group.this.location
  resource_group_name        = azurerm_resource_group.this.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "premium"
  soft_delete_retention_days = 7

  # Allow the user running the apply access to KeyVault. You may want to configure
  # policies for other users/groups in your organization.
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Create",
      "Get",
    ]

    secret_permissions = [
      "Set",
      "Get",
      "List",
      "Delete",
      "Purge",
      "Recover"
    ]
  }

  # Grant the VMSS identity permission to download secrets.
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_user_assigned_identity.vmss.principal_id

    secret_permissions = [
      "Get"
    ]
  }
}

resource "azurerm_key_vault_secret" "worker_pool_config" {
  name         = "worker-pool-config"
  value        = base64encode(var.worker_pool_config)
  key_vault_id = azurerm_key_vault.this.id
}

resource "azurerm_key_vault_secret" "worker_pool_private_key" {
  name         = "worker-pool-private-key"
  value        = base64encode(var.worker_pool_private_key)
  key_vault_id = azurerm_key_vault.this.id
}
