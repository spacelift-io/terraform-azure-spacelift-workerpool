module "autoscaler" {
  count  = local.autoscaling_enabled ? 1 : 0
  source = "./autoscaler"

  autoscaling_configuration = var.autoscaling_configuration
  base_name                 = local.namespace
  key_vault_id              = var.autoscaling_configuration.key_vault_id
  resource_group            = var.resource_group
  spacelift_api_credentials = var.spacelift_api_credentials
  subnet_id                 = var.subnet_id
  tags                      = var.tags
  vmss_resource_id          = azurerm_linux_virtual_machine_scale_set.this.id
  worker_pool_id            = var.worker_pool_id
}
