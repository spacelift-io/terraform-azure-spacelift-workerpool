# Spacelift Worker for Azure

Terraform module for deploying a Spacelift worker pool on Azure using a VMSS.

## Requirements

Module v4 requires AzureRM provider v5 and is not compatible with AzureRM v4.
Use module v3.0.0 if you need to remain on AzureRM v4.

The default VMSS size is `Standard_D2ads_v5`. Ensure the target subscription and
region have sufficient Standard DADSv5 Family and Total Regional vCPU quota, or
set `vmss_sku` to another image-compatible size.

## Usage

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
  }
}

module "azure-worker" {
  source = "github.com/spacelift-io/terraform-azure-spacelift-workerpool?ref=v4.0.0"

  admin_public_key = var.admin_public_key

  configuration = <<-EOT
    export SPACELIFT_TOKEN=${var.worker_pool_config}
    export SPACELIFT_POOL_PRIVATE_KEY=${var.worker_pool_private_key}
  EOT

  resource_group = var.resource_group
  subnet_id      = var.subnet_id
  worker_pool_id = var.worker_pool_id

  autoscaling_configuration = {
    max_create    = 2
    max_terminate = 1
    scale = {
      min = 1
      max = 5
    }
  }

  spacelift_api_credentials = {
    api_key_id       = var.spacelift_api_key_id
    api_key_secret   = var.spacelift_api_key_secret
    api_key_endpoint = var.spacelift_api_key_endpoint
  }
}
```

## Resource Provider Registration

AzureRM v5 does not register Azure Resource Providers automatically. Ensure the
Resource Providers required by your configuration are registered before applying
this module, or configure `resource_providers_to_register` in the `azurerm`
provider block. Enabling the autoscaler requires additional providers for
Storage, App Service, Application Insights, Key Vault, and role assignments.

## Autoscaler Release

The autoscaler defaults to `version = "stable"`, currently pinned to v3.0.2.
You can instead provide an explicit release tag or use `version = "latest"` to
resolve the latest GitHub release to a concrete tag during the Terraform run.

When using `latest`, set `GITHUB_TOKEN` in the Terraform runner environment to
avoid the lower unauthenticated GitHub API rate limit. The resolved version,
architecture, and packaging files determine a stable package hash, so plans do
not drift while the resolved release remains unchanged.

See [Autoscaler Release Download](./AUTOSCALER_DOWNLOAD.md) for version options,
deployment flow, and runner requirements.

## Debugging

The workers VM instances are designed to reboot when the launcher process exits by default. This allows them to recover from certain types of errors and reconnect to Spacelift.

However this can cause a crash-loop situation, for example if there is some kind of configuration error that prevents the launcher connecting to Spacelift correctly. When this happens, it can be difficult to connect to the VM to investigate the problem.

Because of this, the module supports a `process_exit_behavior` variable that can be set to one of the following values:

- `Reboot` - causes the instance to restart (the default behavior).
- `Shutdown` - causes the instance to shutdown.
- `None` - takes no action, allowing you to connect to the instance and investigate issues.

## Accepting Terms

Before you can use our Marketplace image, you need to accept the terms and conditions for the
image for the subscription you want to deploy the image to. You can do this using the following
command:

```shell
az vm image terms accept \
  --publisher "spaceliftinc1625499025476" \
  --offer "spacelift_worker" \
  --plan "ubuntu_20_04"
```

More information can be found [here](https://go.microsoft.com/fwlink/?linkid=2110637).

If using Terraform to accept the terms and conditions, the module needs an explicit dependency to ensure the resources are created in the proper order:

```hcl
resource "azurerm_marketplace_agreement" "spacelift_worker" {
  publisher = "spaceliftinc1625499025476"
  offer     = "spacelift_worker"
  plan      = "ubuntu_20_04"
}

module "azure-worker" {
  source     = "github.com/spacelift-io/terraform-azure-spacelift-workerpool?ref=v4.0.0"
  depends_on = [ azurerm_marketplace_agreement.spacelift_worker ]

  [...]
}
```

More information can be found [here](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/marketplace_agreement.html).

## Marketplace Image

The default image used by this module comes from the [spacelift-worker-image](https://github.com/spacelift-io/spacelift-worker-image)
repository. You can find the latest image details on the [releases](https://github.com/spacelift-io/spacelift-worker-image/releases)
page.

This module automatically uses the FedRAMP worker image for FedRAMP worker pools.

## Examples

The following examples of using the module are available:

- [Autoscaler](./examples/autoscaler/README.md) - creates a worker with the autoscaler enabled,
  using an Azure Function to automatically scale the VMSS based on queue depth.
- [Bastion](./examples/bastion/README.md) - creates a worker with a Bastion host for ssh access.
- [System-Assigned Identity](./examples/system-assigned-identity/README.md) - creates a worker
  with a system-assigned identity.
- [User-Assigned Identity](./examples/user-assigned-identity/README.md) - creates a worker with
  a user-assigned identity, and shows how to use that identity to access the worker pool credentials
  via KeyVault secrets.
