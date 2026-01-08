# IAM/RBAC configuration for the autoscaler Function App
# The Function App needs permissions to manage the VMSS instances

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

output "autoscaler_identity_principal_id" {
  value       = var.autoscaling_enabled ? azurerm_linux_function_app.autoscaler[0].identity[0].principal_id : null
  description = "The principal ID of the autoscaler Function App's managed identity"
}
