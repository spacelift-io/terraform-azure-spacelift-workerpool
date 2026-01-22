output "identity" {
  value = azurerm_linux_virtual_machine_scale_set.this.identity
}

output "vmss_id" {
  value       = azurerm_linux_virtual_machine_scale_set.this.id
  description = "The ID of the Virtual Machine Scale Set."
}

output "vmss_name" {
  value       = azurerm_linux_virtual_machine_scale_set.this.name
  description = "The name of the Virtual Machine Scale Set."
}

output "autoscaler_identity_principal_id" {
  value       = local.autoscaling_enabled ? module.autoscaler[0].identity_principal_id : null
  description = "The principal ID of the autoscaler Function App's managed identity."
}

output "autoscaler_function_app_name" {
  value       = local.autoscaling_enabled ? module.autoscaler[0].function_app_name : null
  description = "The name of the autoscaler Function App."
}
