# Create a user-assigned identity for the VMSS. This allows us to grant it permissions
# over our subscription, as well as configure its access to KeyVault secrets.
resource "azurerm_user_assigned_identity" "vmss" {
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  name                = "sp5ft-${var.worker_pool_id}"
}

# Uncomment the following resource to grant the VMSS instances access to your current subscription.
# resource "azurerm_role_assignment" "vmss_contributor" {
#   scope                = data.azurerm_subscription.primary.id
#   role_definition_name = "Contributor"
#   principal_id         = azurerm_user_assigned_identity.vmss.principal_id
# }
