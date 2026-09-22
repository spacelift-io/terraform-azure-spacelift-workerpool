locals {
  download_folder = var.worker_pool_id
  architecture    = coalesce(var.autoscaling_configuration.architecture, "amd64")

  autoscaler_zip            = "${local.download_folder}/ec2-workerpool-autoscaler_azurefunc_linux_${local.architecture}.zip"
  resolve_latest            = var.autoscaling_configuration.version == "latest"
  stable_autoscaler_version = "v3.0.0"
  autoscaler_version        = var.autoscaling_configuration.version == "stable" ? local.stable_autoscaler_version : (local.resolve_latest ? jsondecode(data.http.latest_release[0].response_body).tag_name : var.autoscaling_configuration.version)
  function_name             = "${var.base_name}-vmss-autoscaler"

  function_package_dir  = "${path.module}/function_package"
  generated_package_zip = "${local.download_folder}/autoscaler-function.zip"
  package_hash = sha256(jsonencode({
    version        = local.autoscaler_version
    architecture   = local.architecture
    package_script = filesha256("${local.function_package_dir}/package.sh")
    host_json      = filesha256("${local.function_package_dir}/host.json")
    function_json  = filesha256("${local.function_package_dir}/AutoscalerTimer/function.json")
  }))
}

# Resolve "latest" to a concrete release tag to avoid perpetual plan drift.
data "http" "latest_release" {
  count = local.resolve_latest ? 1 : 0
  url   = "https://api.github.com/repos/spacelift-io/ec2-workerpool-autoscaler/releases/latest"

  request_headers = merge(
    { Accept = "application/vnd.github+json" },
    local.github_auth_header,
  )

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Failed to fetch the latest autoscaler release (HTTP ${self.status_code}). Set GITHUB_TOKEN to avoid rate limits or pin a specific version."
    }
  }
}

# Read GITHUB_TOKEN from the environment to authenticate GitHub API requests.
data "external" "github_auth_header" {
  count = local.resolve_latest ? 1 : 0
  program = [
    "sh", "-c",
    <<-EOT
      if [ -n "$GITHUB_TOKEN" ]; then
        printf '{"Authorization":"Bearer %s"}' "$GITHUB_TOKEN"
      else
        printf '{}'
      fi
    EOT
  ]
}

locals {
  github_auth_header = local.resolve_latest ? data.external.github_auth_header[0].result : {}
}

# Download the concrete autoscaler release during apply.
resource "null_resource" "download" {
  triggers = {
    version      = local.autoscaler_version
    architecture = local.architecture
  }

  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p "${local.download_folder}"
      curl -sfL -o "${local.autoscaler_zip}" \
        "https://github.com/spacelift-io/ec2-workerpool-autoscaler/releases/download/${local.autoscaler_version}/ec2-workerpool-autoscaler_azurefunc_linux_${local.architecture}.zip"
    EOT
  }
}

resource "null_resource" "package" {
  depends_on = [null_resource.download]

  triggers = {
    package_hash = local.package_hash
  }

  provisioner "local-exec" {
    command = "${local.function_package_dir}/package.sh ${local.autoscaler_zip} ${local.generated_package_zip}"
  }
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
  name                 = "autoscaler-function-${local.package_hash}.zip"
  storage_container_id = azurerm_storage_container.autoscaler.id
  type                 = "Block"
  source               = local.generated_package_zip

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
