terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.61"
    }
  }
}

provider "azurerm" {
  features {}
}

# Create a resource group for the example
resource "azurerm_resource_group" "example" {
  name     = "spacelift-workers-autoscaling-example"
  location = "eastus"
}

# Create a virtual network
resource "azurerm_virtual_network" "example" {
  name                = "spacelift-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
}

# Create a subnet
resource "azurerm_subnet" "example" {
  name                 = "spacelift-subnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Deploy Spacelift worker pool with autoscaling enabled
module "spacelift_worker_pool" {
  source = "../../"

  # Basic configuration
  resource_group = {
    name     = azurerm_resource_group.example.name
    location = azurerm_resource_group.example.location
    id       = azurerm_resource_group.example.id
  }
  subnet_id      = azurerm_subnet.example.id
  worker_pool_id = var.worker_pool_id

  # Worker configuration
  admin_password = var.admin_password # Or use admin_public_key for SSH
  configuration  = <<-EOT
    export SPACELIFT_TOKEN="${var.worker_pool_config}"
    export SPACELIFT_POOL_PRIVATE_KEY="${var.worker_pool_private_key}"
  EOT

  # VMSS configuration
  vmss_instances = 0 # Initial capacity
  vmss_sku       = "Standard_B2s"

  # Enable autoscaling
  autoscaling_enabled = true

  # Autoscaling configuration
  autoscaling_configuration = {
    schedule_expression = "0 */5 * * * *" # Every 5 minutes
    max_create          = 2               # Scale up by max 2 instances per cycle
    max_terminate       = 2               # Scale down by max 2 instances per cycle
    scale_down_delay    = 5               # Wait 5 minutes before scaling down new instances
    timeout             = 300             # Function timeout in seconds
    min_idle_workers    = 0               # Maintain at least 1 idle worker
  }

  # Spacelift API credentials for autoscaler
  spacelift_api_key_id     = var.spacelift_api_key_id
  spacelift_api_key_secret = var.spacelift_api_key_secret
  spacelift_api_endpoint   = "https://my-first-env.app.spacelift.io"

  # Tags
  tags = {
    Environment = "example"
    Purpose     = "autoscaling-demo"
    # Add capacity constraints as tags for the autoscaler
    MinCapacity = "0"
    MaxCapacity = "2"
  }
}

# Outputs
output "vmss_id" {
  value       = module.spacelift_worker_pool.vmss_id
  description = "The ID of the Virtual Machine Scale Set"
}

output "autoscaler_function_app_name" {
  value       = module.spacelift_worker_pool.autoscaler_function_app_name
  description = "The name of the autoscaler Function App"
}

output "autoscaler_application_insights_id" {
  value       = module.spacelift_worker_pool.autoscaler_application_insights_id
  description = "Application Insights ID for monitoring the autoscaler"
}
