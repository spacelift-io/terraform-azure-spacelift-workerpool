# RBAC configuration for the autoscaler Function App
# The Function App needs permissions to manage the VMSS instances

# Role assignment: Virtual Machine Contributor on the VMSS
# This allows the Function App to:
# - Read VMSS instances
# - Scale the VMSS capacity
# - Deallocate and delete specific instances
resource "azurerm_role_assignment" "autoscaler_vmss" {
  scope                = var.vmss_resource_id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azurerm_linux_function_app.autoscaler.identity[0].principal_id
}

# Role assignment: Reader on the Resource Group
# This allows the Function App to discover and read resource metadata
resource "azurerm_role_assignment" "autoscaler_rg_reader" {
  scope                = var.resource_group.id
  role_definition_name = "Reader"
  principal_id         = azurerm_linux_function_app.autoscaler.identity[0].principal_id
}

# Role assignment: Network Contributor on the Subnet
# This allows the Function App to join new VMSS instances to the subnet during scale-up
resource "azurerm_role_assignment" "autoscaler_subnet" {
  scope                = var.subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_linux_function_app.autoscaler.identity[0].principal_id
}
