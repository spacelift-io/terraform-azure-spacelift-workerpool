# Autoscaler resources for Spacelift worker pool
# This file contains the Azure Function App that scales the VMSS based on Spacelift queue metrics

# Storage account for the Function App
resource "azurerm_storage_account" "autoscaler" {
  count = var.autoscaling_enabled ? 1 : 0

  name                     = "spaceliftautoscaler"
  resource_group_name      = var.resource_group.name
  location                 = var.resource_group.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = merge(var.tags, {
    WorkerPoolID = var.worker_pool_id
    Component    = "Autoscaler"
  })
}

# App Service Plan for the Function App
resource "azurerm_service_plan" "autoscaler" {
  count = var.autoscaling_enabled ? 1 : 0

  name                = "${local.namespace}-autoscaler-plan"
  resource_group_name = var.resource_group.name
  location            = var.resource_group.location
  os_type             = "Linux"
  sku_name            = "B1"

  tags = merge(var.tags, {
    WorkerPoolID = var.worker_pool_id
    Component    = "Autoscaler"
  })
}

# Linux Function App for autoscaling
resource "azurerm_linux_function_app" "autoscaler" {
  count = var.autoscaling_enabled ? 1 : 0

  name                = "${local.namespace}-autoscaler"
  resource_group_name = var.resource_group.name
  location            = var.resource_group.location

  storage_account_name       = azurerm_storage_account.autoscaler[0].name
  storage_account_access_key = azurerm_storage_account.autoscaler[0].primary_access_key
  service_plan_id            = azurerm_service_plan.autoscaler[0].id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      # Using a custom handler for Go
      use_custom_runtime = true
    }

    # Enable application insights for monitoring
    application_insights_connection_string = azurerm_application_insights.autoscaler[0].connection_string
  }

  app_settings = {
    # Azure Function settings
    FUNCTIONS_WORKER_RUNTIME        = "custom"
    WEBSITE_RUN_FROM_PACKAGE        = "1"
    AzureWebJobsDisableHomepage     = "true"
    WEBSITE_ENABLE_SYNC_UPDATE_SITE = "true"

    # Autoscaler configuration
    SCHEDULE_EXPRESSION = var.autoscaling_configuration.schedule_expression
    MAX_CREATE          = var.autoscaling_configuration.max_create
    MAX_TERMINATE       = var.autoscaling_configuration.max_terminate
    SCALE_DOWN_DELAY    = var.autoscaling_configuration.scale_down_delay
    MIN_IDLE_WORKERS    = var.autoscaling_configuration.min_idle_workers

    # Azure VMSS configuration
    AZURE_SUBSCRIPTION_ID = data.azurerm_client_config.current.subscription_id
    VMSS_RESOURCE_GROUP   = var.resource_group.name
    VMSS_NAME             = azurerm_linux_virtual_machine_scale_set.this.name

    # Spacelift API configuration
    SPACELIFT_API_ENDPOINT   = var.spacelift_api_endpoint
    SPACELIFT_API_KEY_ID     = var.spacelift_api_key_id
    SPACELIFT_API_KEY_SECRET = var.spacelift_api_key_secret
    SPACELIFT_WORKER_POOL_ID = var.worker_pool_id
  }

  tags = merge(var.tags, {
    WorkerPoolID = var.worker_pool_id
    Component    = "Autoscaler"
  })

  lifecycle {
    precondition {
      condition     = !var.autoscaling_enabled || (var.spacelift_api_key_id != null && var.spacelift_api_key_secret != null)
      error_message = "When autoscaling_enabled is true, both spacelift_api_key_id and spacelift_api_key_secret must be provided."
    }
  }
}

# Application Insights for monitoring the Function App
resource "azurerm_application_insights" "autoscaler" {
  count = var.autoscaling_enabled ? 1 : 0

  name                = "${local.namespace}-autoscaler-insights"
  resource_group_name = var.resource_group.name
  location            = var.resource_group.location
  application_type    = "other"

  tags = merge(var.tags, {
    WorkerPoolID = var.worker_pool_id
    Component    = "Autoscaler"
  })
}

# Data source to get current Azure client config
data "azurerm_client_config" "current" {}
