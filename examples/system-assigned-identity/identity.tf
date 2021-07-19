# Uncomment the following resource to grant the VMSS instances access to your current subscription.
# resource "azurerm_role_assignment" "vmss_contributor" {
#   scope                = data.azurerm_subscription.primary.id
#   role_definition_name = "Contributor"
#   principal_id         = module.azure-worker.identity[0].principal_id
# }
