# IAM/RBAC configuration for the autoscaler Function App
# The Function App needs permissions to manage the VMSS instances and access Key Vault

# Get the VMSS resource ID for role assignment
data "azurerm_virtual_machine_scale_set" "this" {
  count = var.autoscaling_enabled ? 1 : 0

  name                = azurerm_linux_virtual_machine_scale_set.this.name
  resource_group_name = var.resource_group.name
}

# Role assignment: Virtual Machine Contributor on the VMSS
# This allows the Function App to:
# - Read VMSS instances
# - Scale the VMSS capacity
# - Deallocate and delete specific instances
resource "azurerm_role_assignment" "autoscaler_vmss" {
  count = var.autoscaling_enabled ? 1 : 0

  scope                = azurerm_linux_virtual_machine_scale_set.this.id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azurerm_linux_function_app.autoscaler[0].identity[0].principal_id
}

# Role assignment: Reader on the Resource Group
# This allows the Function App to discover and read resource metadata
resource "azurerm_role_assignment" "autoscaler_rg_reader" {
  count = var.autoscaling_enabled ? 1 : 0

  scope                = var.resource_group.id
  role_definition_name = "Reader"
  principal_id         = azurerm_linux_function_app.autoscaler[0].identity[0].principal_id
}

# Role assignment: Key Vault Secrets User on the Key Vault
# This allows the Function App to read secrets from the Key Vault
resource "azurerm_role_assignment" "autoscaler_keyvault" {
  count = var.autoscaling_enabled ? 1 : 0

  scope                = local.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_function_app.autoscaler[0].identity[0].principal_id
}

# Output the managed identity principal ID for reference
output "autoscaler_identity_principal_id" {
  value       = var.autoscaling_enabled ? azurerm_linux_function_app.autoscaler[0].identity[0].principal_id : null
  description = "The principal ID of the autoscaler Function App's managed identity"
}
