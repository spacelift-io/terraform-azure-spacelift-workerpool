# Spacelift Worker for Azure

Terraform module for deploying a Spacelift worker pool on Azure using a VMSS.

## Usage

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.61.0"
    }
  }
}

module "azure-worker" {
  source = "github.com/spacelift-io/terraform-azure-spacelift-workerpool?ref=v1.0.0"

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
