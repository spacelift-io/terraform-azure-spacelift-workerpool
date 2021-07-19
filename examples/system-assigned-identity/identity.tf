# Grant the VMSS instances access to our current subscription. You may want to remove this
# and grant permissions separately, or grant more restrictive permissions.
resource "azurerm_role_assignment" "vmss_contributor" {
  scope                = data.azurerm_subscription.primary.id
  role_definition_name = "Contributor"
  principal_id         = module.azure-worker.identity[0].principal_id
}
