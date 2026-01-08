# Autoscaler resources for Spacelift worker pool
# This file contains the Azure Function App that scales the VMSS based on Spacelift queue metrics
# Uses the company-approved autoscaler binary with Azure custom handler

locals {
  autoscaler_package_path = "${path.module}/function_package/autoscaler-function.zip"
  vmss_resource_id        = azurerm_linux_virtual_machine_scale_set.this.id
}

# Create deployment package from bootstrap binary
resource "null_resource" "package_autoscaler" {
  count = var.autoscaling_enabled && var.autoscaling_configuration.binary_source == "local" ? 1 : 0

  triggers = {
    # Rebuild if binary changes
    binary_hash = filesha256("${path.module}/bootstrap")
    # Rebuild if package script changes
    script_hash = filesha256("${path.module}/function_package/package.sh")
  }

  provisioner "local-exec" {
    command     = "./package.sh"
    working_dir = "${path.module}/function_package"
  }
}

# Storage account for the Function App
resource "azurerm_storage_account" "autoscaler" {
  count = var.autoscaling_enabled ? 1 : 0

  name                     = lower(substr(replace("${local.namespace}autoscaler", "-", ""), 0, 24))
  resource_group_name      = var.resource_group.name
  location                 = var.resource_group.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = merge(var.tags, {
    WorkerPoolID = var.worker_pool_id
    Component    = "Autoscaler"
  })
}

# Upload the function package to blob storage
resource "azurerm_storage_container" "autoscaler" {
  count = var.autoscaling_enabled ? 1 : 0

  name                  = "function-releases"
  storage_account_id    = azurerm_storage_account.autoscaler[0].id
  container_access_type = "private"
}

resource "azurerm_storage_blob" "autoscaler" {
  count = var.autoscaling_enabled && var.autoscaling_configuration.binary_source == "local" ? 1 : 0

  name                   = "autoscaler-function-${filesha256(local.autoscaler_package_path)}.zip"
  storage_account_name   = azurerm_storage_account.autoscaler[0].name
  storage_container_name = azurerm_storage_container.autoscaler[0].name
  type                   = "Block"
  source                 = local.autoscaler_package_path

  depends_on = [null_resource.package_autoscaler]
}

# Generate SAS token for the blob
data "azurerm_storage_account_blob_container_sas" "autoscaler" {
  count = var.autoscaling_enabled && var.autoscaling_configuration.binary_source == "local" ? 1 : 0

  connection_string = azurerm_storage_account.autoscaler[0].primary_connection_string
  container_name    = azurerm_storage_container.autoscaler[0].name

  start  = "2024-01-01T00:00:00Z"
  expiry = "2030-01-01T00:00:00Z"

  permissions {
    read   = true
    add    = false
    create = false
    write  = false
    delete = false
    list   = false
  }
}

# App Service Plan for the Function App
resource "azurerm_service_plan" "autoscaler" {
  count = var.autoscaling_enabled ? 1 : 0

  name                = "${local.namespace}-autoscaler-plan"
  resource_group_name = var.resource_group.name
  location            = var.resource_group.location
  os_type             = "Linux"
  sku_name            = "S1"

  tags = merge(var.tags, {
    WorkerPoolID = var.worker_pool_id
    Component    = "Autoscaler"
  })
}

# Linux Function App for autoscaling using custom handler
resource "azurerm_linux_function_app" "autoscaler" {
  count = var.autoscaling_enabled ? 1 : 0

  name                = "${local.namespace}-autoscaler"
  resource_group_name = var.resource_group.name
  location            = var.resource_group.location

  storage_account_name       = azurerm_storage_account.autoscaler[0].name
  storage_account_access_key = azurerm_storage_account.autoscaler[0].primary_access_key
  service_plan_id            = azurerm_service_plan.autoscaler[0].id

  # Enable system-assigned managed identity for Azure resource access
  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      use_custom_runtime = true
    }

    application_insights_connection_string = azurerm_application_insights.autoscaler[0].connection_string
    application_insights_key               = azurerm_application_insights.autoscaler[0].instrumentation_key

    cors {
      allowed_origins = ["https://portal.azure.com"]
    }
  }

  app_settings = {
    # Azure Function runtime settings
    FUNCTIONS_WORKER_RUNTIME = "custom"
    # Run from the package in blob storage
    WEBSITE_RUN_FROM_PACKAGE                  = var.autoscaling_configuration.binary_source == "local" ? "${azurerm_storage_blob.autoscaler[0].url}${data.azurerm_storage_account_blob_container_sas.autoscaler[0].sas}" : "0"
    AzureWebJobsDisableHomepage               = "true"
    WEBSITE_ENABLE_SYNC_UPDATE_SITE           = "true"
    WEBSITE_MAX_DYNAMIC_APPLICATION_SCALE_OUT = "1"

    # Timer trigger schedule (cron format for Azure Functions)
    SCHEDULE_EXPRESSION = var.autoscaling_configuration.schedule_expression

    # Spacelift API configuration (required by bootstrap binary)
    SPACELIFT_API_KEY_ID          = var.spacelift_api_key_id
    SPACELIFT_API_KEY_SECRET_NAME = azurerm_key_vault_secret.spacelift_api_key[0].versionless_id
    SPACELIFT_API_KEY_ENDPOINT    = var.spacelift_api_endpoint
    SPACELIFT_WORKER_POOL_ID      = var.worker_pool_id

    # Azure VMSS configuration (required by bootstrap binary)
    AUTOSCALING_GROUP_ARN = local.vmss_resource_id
    AUTOSCALING_REGION    = var.resource_group.location

    # Autoscaling limits (optional, have defaults in binary)
    AUTOSCALING_MAX_CREATE            = var.autoscaling_configuration.max_create
    AUTOSCALING_MAX_KILL              = var.autoscaling_configuration.max_terminate
    AUTOSCALING_SCALE_DOWN_DELAY      = var.autoscaling_configuration.scale_down_delay
    AUTOSCALING_CAPACITY_SANITY_CHECK = var.autoscaling_configuration.capacity_sanity_check
  }

  tags = merge(var.tags, {
    WorkerPoolID = var.worker_pool_id
    Component    = "Autoscaler"
  })

  lifecycle {
    precondition {
      condition     = !var.autoscaling_enabled || (var.spacelift_api_key_id != null && var.spacelift_api_key_secret != null && var.spacelift_api_endpoint != null)
      error_message = "When autoscaling_enabled is true, spacelift_api_key_id, spacelift_api_key_secret, and spacelift_api_endpoint must be provided."
    }

    precondition {
      condition     = !var.autoscaling_enabled || var.autoscaling_configuration.binary_source == "local" || var.autoscaling_configuration.binary_download_url != null
      error_message = "When binary_source is 'download', binary_download_url must be provided."
    }

    # Ignore changes to zip_deploy_file to prevent constant redeployment
    ignore_changes = [
      zip_deploy_file
    ]
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
