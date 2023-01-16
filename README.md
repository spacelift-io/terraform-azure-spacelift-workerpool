# Spacelift Worker for Azure

Terraform module for deploying a Spacelift worker pool on Azure using a VMSS.

## Usage

NOTE: please make sure you [accept the terms](#accepting-terms) for our Azure Marketplace
image before trying to use the module.

```hcl
terraform {
  required_providers {
    google = {
      source  = "hashicorp/azurerm"
      version = "~> 2.68.0"
    }
  }
}

module "azure-worker" {
  source = "github.com/spacelift-io/terraform-azure-spacelift-workerpool?ref=v0.0.6"

  admin_password = "Super Secret Password!"

  configuration = <<-EOT
    export SPACELIFT_TOKEN="${var.worker_pool_config}"
    export SPACELIFT_POOL_PRIVATE_KEY="${var.worker_pool_private_key}"
  EOT

  resource_group = var.resource_group # An azurerm_resource_group object - must have `name` and `location` properties
  subnet_id      = var.subnet_id
  worker_pool_id = var.worker_pool_id
}
```

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

## Marketplace Image

The default image used by this module comes from the [spacelift-worker-image](https://github.com/spacelift-io/spacelift-worker-image)
repository. You can find the latest image details on the [releases](https://github.com/spacelift-io/spacelift-worker-image/releases)
page.

## Examples

The following examples of using the module are available:

- [Bastion](./examples/bastion/README.md) - creates a worker with a Bastion host for ssh access.
- [System-Assigned Identity](./examples/system-assigned-identity/README.md) - creates a worker
  with a system-assigned identity.
- [User-Assigned Identity](./examples/user-assigned-identity/README.md) - creates a worker with
  a user-assigned identity, and shows how to use that identity to access the worker pool credentials
  via KeyVault secrets.
