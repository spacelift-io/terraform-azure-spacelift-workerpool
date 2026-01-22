output "identity_principal_id" {
  value       = azurerm_linux_function_app.autoscaler.identity[0].principal_id
  description = "The principal ID of the autoscaler Function App's managed identity"
}

output "function_app_name" {
  value       = azurerm_linux_function_app.autoscaler.name
  description = "The name of the autoscaler Function App"
}

output "key_vault_secret_url" {
  value       = azurerm_key_vault_secret.spacelift_api_key.versionless_id
  description = "The URL of the Spacelift API key secret in Key Vault"
  sensitive   = true
}

output "application_insights_instrumentation_key" {
  value       = azurerm_application_insights.autoscaler.instrumentation_key
  description = "The instrumentation key for Application Insights"
  sensitive   = true
}

output "application_insights_connection_string" {
  value       = azurerm_application_insights.autoscaler.connection_string
  description = "The connection string for Application Insights"
  sensitive   = true
}
