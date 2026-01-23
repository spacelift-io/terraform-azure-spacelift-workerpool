locals {
  download_folder = var.worker_pool_id
  architecture    = coalesce(var.autoscaling_configuration.architecture, "amd64")

  # TODO:// might need to rename this after repo name changes
  autoscaler_zip     = "${local.download_folder}/ec2-workerpool-autoscaler_azurefunc_linux_${local.architecture}.zip"
  autoscaler_version = coalesce(var.autoscaling_configuration.version, "latest")
  function_name      = "${var.base_name}-vmss-autoscaler"

  function_package_dir  = "${path.module}/function_package"
  generated_package_zip = "${local.download_folder}/autoscaler-function.zip"
}

# Download the autoscaler binary from GitHub releases
resource "null_resource" "download" {
  triggers = {
    # Always re-download if version is "latest" or if the file doesn't exist
    keeper = (
      local.autoscaler_version == "latest" || !fileexists(local.autoscaler_zip)
      ? timestamp()
      : local.autoscaler_version
    )
  }

  provisioner "local-exec" {
    command = "${path.module}/download.sh ${local.autoscaler_version} ${local.architecture} ${local.download_folder}"
  }
}

resource "null_resource" "package" {
  depends_on = [null_resource.download]

  triggers = {
    download_trigger = null_resource.download.id
    script_hash      = filesha256("${local.function_package_dir}/package.sh")
    host_json_hash   = filesha256("${local.function_package_dir}/host.json")
    function_hash    = filesha256("${local.function_package_dir}/AutoscalerTimer/function.json")
  }

  provisioner "local-exec" {
    command = "${local.function_package_dir}/package.sh ${local.autoscaler_zip} ${local.generated_package_zip}"
  }
}

data "local_file" "function_package" {
  depends_on = [null_resource.package]
  filename   = local.generated_package_zip
}

# Storage account for the Function App
resource "azurerm_storage_account" "autoscaler" {
  name                     = lower(substr(replace("${var.base_name}auto", "-", ""), 0, 24))
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
  name                  = "function-releases"
  storage_account_id    = azurerm_storage_account.autoscaler.id
  container_access_type = "private"
}

resource "azurerm_storage_blob" "autoscaler" {
  name                   = "autoscaler-function-${data.local_file.function_package.content_base64sha256}.zip"
  storage_account_name   = azurerm_storage_account.autoscaler.name
  storage_container_name = azurerm_storage_container.autoscaler.name
  type                   = "Block"
  source                 = local.generated_package_zip

  depends_on = [null_resource.package]
}

# Grant the Function App's managed identity read access to the blob storage
# This allows WEBSITE_RUN_FROM_PACKAGE to work without a SAS token
resource "azurerm_role_assignment" "autoscaler_blob_reader" {
  scope                = azurerm_storage_account.autoscaler.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_linux_function_app.autoscaler.identity[0].principal_id
}

# App Service Plan for the Function App
resource "azurerm_service_plan" "autoscaler" {
  name                = "${var.base_name}-autoscaler-plan"
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
  name                = local.function_name
  resource_group_name = var.resource_group.name
  location            = var.resource_group.location

  storage_account_name       = azurerm_storage_account.autoscaler.name
  storage_account_access_key = azurerm_storage_account.autoscaler.primary_access_key
  service_plan_id            = azurerm_service_plan.autoscaler.id

  # Enable system-assigned managed identity for Azure resource access
  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      use_custom_runtime = true
    }

    application_insights_connection_string = azurerm_application_insights.autoscaler.connection_string
    application_insights_key               = azurerm_application_insights.autoscaler.instrumentation_key

    cors {
      allowed_origins = ["https://portal.azure.com"]
    }
  }

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME                     = "custom"
    WEBSITE_RUN_FROM_PACKAGE                     = azurerm_storage_blob.autoscaler.url
    WEBSITE_RUN_FROM_PACKAGE_BLOB_MI_RESOURCE_ID = ""
    AzureWebJobsDisableHomepage                  = "true"
    WEBSITE_ENABLE_SYNC_UPDATE_SITE              = "true"
    WEBSITE_MAX_DYNAMIC_APPLICATION_SCALE_OUT    = "1"

    # Timer trigger schedule (cron format for Azure Functions)
    SCHEDULE_EXPRESSION = coalesce(var.autoscaling_configuration.schedule_expression, "0 * * * * *")

    # Spacelift API configuration
    SPACELIFT_API_KEY_ID          = var.spacelift_api_credentials.api_key_id
    SPACELIFT_API_KEY_ENDPOINT    = var.spacelift_api_credentials.api_key_endpoint
    SPACELIFT_API_KEY_SECRET_NAME = azurerm_key_vault_secret.spacelift_api_key.name
    SPACELIFT_WORKER_POOL_ID      = var.worker_pool_id

    # Azure Key Vault configuration
    AZURE_KEY_VAULT_NAME = var.key_vault_id != null ? split("/", var.key_vault_id)[8] : azurerm_key_vault.autoscaler[0].name
    AZURE_SECRET_NAME    = azurerm_key_vault_secret.spacelift_api_key.name

    # Azure VMSS configuration
    AUTOSCALING_GROUP_ARN = var.vmss_resource_id
    AUTOSCALING_REGION    = var.resource_group.location

    # Autoscaling limits
    AUTOSCALING_MAX_CREATE       = var.autoscaling_configuration.max_create != null ? var.autoscaling_configuration.max_create : 1
    AUTOSCALING_MAX_KILL         = var.autoscaling_configuration.max_terminate != null ? var.autoscaling_configuration.max_terminate : 1
    AUTOSCALING_SCALE_DOWN_DELAY = var.autoscaling_configuration.scale_down_delay != null ? var.autoscaling_configuration.scale_down_delay : 0

    AZURE_AUTOSCALING_MIN_SIZE = coalesce(try(var.autoscaling_configuration.scale.min, null), -1)
    AZURE_AUTOSCALING_MAX_SIZE = coalesce(try(var.autoscaling_configuration.scale.max, null), 5)
  }

  tags = merge(var.tags, {
    WorkerPoolID = var.worker_pool_id
    Component    = "Autoscaler"
  })

  lifecycle {
    # Ignore changes to zip_deploy_file to prevent constant redeployment
    ignore_changes = [
      zip_deploy_file
    ]
  }
}

# Application Insights for monitoring the Function App
resource "azurerm_application_insights" "autoscaler" {
  name                = "${var.base_name}-autoscaler-insights"
  resource_group_name = var.resource_group.name
  location            = var.resource_group.location
  application_type    = "other"

  tags = merge(var.tags, {
    WorkerPoolID = var.worker_pool_id
    Component    = "Autoscaler"
  })
}
