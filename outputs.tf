output "identity" {
  value = azurerm_linux_virtual_machine_scale_set.this.identity
}

output "vmss_id" {
  value       = azurerm_linux_virtual_machine_scale_set.this.id
  description = "The ID of the Virtual Machine Scale Set"
}

output "vmss_name" {
  value       = azurerm_linux_virtual_machine_scale_set.this.name
  description = "The name of the Virtual Machine Scale Set"
}

# Autoscaler outputs
output "autoscaler_enabled" {
  value       = var.autoscaling_enabled
  description = "Whether autoscaling is enabled"
}

output "autoscaler_function_app_name" {
  value       = var.autoscaling_enabled ? azurerm_linux_function_app.autoscaler[0].name : null
  description = "The name of the autoscaler Function App"
}

output "autoscaler_function_app_id" {
  value       = var.autoscaling_enabled ? azurerm_linux_function_app.autoscaler[0].id : null
  description = "The ID of the autoscaler Function App"
}

output "autoscaler_identity" {
  value       = var.autoscaling_enabled ? azurerm_linux_function_app.autoscaler[0].identity : null
  description = "The managed identity of the autoscaler Function App"
}

output "autoscaler_application_insights_id" {
  value       = var.autoscaling_enabled ? azurerm_application_insights.autoscaler[0].id : null
  description = "The ID of the Application Insights instance for the autoscaler"
}
