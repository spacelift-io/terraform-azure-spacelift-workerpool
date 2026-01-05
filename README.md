# Spacelift Worker for Azure

Terraform module for deploying a Spacelift worker pool on Azure using a VMSS.

## Usage

### Basic Usage

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
  source = "github.com/spacelift-io/terraform-azure-spacelift-workerpool?ref=v1.1.1"

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

### Usage with Autoscaling

```hcl
module "azure-worker" {
  source = "github.com/spacelift-io/terraform-azure-spacelift-workerpool?ref=v1.1.1"

  admin_password = "Super Secret Password!"

  configuration = <<-EOT
    export SPACELIFT_TOKEN="${var.worker_pool_config}"
    export SPACELIFT_POOL_PRIVATE_KEY="${var.worker_pool_private_key}"
  EOT

  resource_group = var.resource_group
  subnet_id      = var.subnet_id
  worker_pool_id = var.worker_pool_id

  # Enable autoscaling
  autoscaling_enabled = true

  # Autoscaling configuration
  autoscaling_configuration = {
    schedule_expression = "0 */5 * * * *"  # Every 5 minutes
    max_create          = 2                 # Scale up by max 2 instances per cycle
    max_terminate       = 1                 # Scale down by max 1 instance per cycle
    scale_down_delay    = 5                 # Wait 5 minutes before scaling down
    min_idle_workers    = 1                 # Maintain at least 1 idle worker
  }

  # Spacelift API credentials for autoscaler
  spacelift_api_key_id     = var.spacelift_api_key_id
  spacelift_api_key_secret = var.spacelift_api_key_secret
  spacelift_api_endpoint   = "https://your-account.app.spacelift.io"

  # Set capacity constraints via tags
  tags = {
    MinCapacity = "1"
    MaxCapacity = "10"
  }
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

This module automatically uses the FedRAMP worker image for FedRAMP worker pools.

## Autoscaling

This module supports optional autoscaling of worker pool instances based on the Spacelift queue length.

### How It Works

The autoscaling feature deploys an Azure Function that:

1. **Monitors** the Spacelift worker pool queue every 5 minutes (configurable)
2. **Scales up** when there are more schedulable runs than idle workers
3. **Scales down** when there are excess idle workers
4. **Cleans up** stray instances (running >10 minutes but not registered with Spacelift)
5. **Gracefully drains** workers before termination

### Architecture

- **Azure Function** (Consumption plan) - runs the autoscaling logic
- **Managed Identity** - provides secure access to the VMSS
- **Application Insights** - monitors autoscaler execution
- **Go runtime** - ports the proven AWS autoscaler logic to Azure

### Prerequisites

To use autoscaling, you need:

1. A Spacelift API key with permissions to:
   - Read worker pool metrics (`worker_pool:read`)
   - List and manage workers (`worker:read`, `worker:write`)
2. Set capacity constraints via VMSS tags (`MinCapacity`, `MaxCapacity`)

### Configuration

See the [autoscaling example](./examples/autoscaling/README.md) for a complete configuration.

Key parameters:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `autoscaling_enabled` | Enable/disable autoscaling | `false` |
| `schedule_expression` | Cron expression for autoscaler runs | `0 */5 * * * *` (every 5 min) |
| `max_create` | Max instances to add per cycle | `1` |
| `max_terminate` | Max instances to remove per cycle | `1` |
| `scale_down_delay` | Minutes before new instances can be terminated | `5` |
| `min_idle_workers` | Minimum idle workers to maintain | `0` |

### Deploying the Autoscaler

The autoscaler code is located in the `autoscaler/` directory. To deploy:

1. **Build the autoscaler**:
   ```bash
   cd autoscaler
   make build
   make package
   ```

2. **Deploy to Azure Function**:
   ```bash
   az functionapp deployment source config-zip \
     -g <resource-group> \
     -n <function-app-name> \
     --src deploy.zip
   ```

3. **Verify deployment**:
   ```bash
   az functionapp show -g <resource-group> -n <function-app-name>
   ```

The Terraform module will create the Function App infrastructure; you just need to deploy the code package.

### Monitoring

Monitor autoscaling operations via:

- **Application Insights**: View execution traces and metrics
- **Function App Logs**: Check detailed autoscaler logs
- **VMSS Activity Log**: See scaling operations

## Examples

The following examples of using the module are available:

- [Autoscaling](./examples/autoscaling/README.md) - demonstrates autoscaling configuration with detailed guidance.
- [Bastion](./examples/bastion/README.md) - creates a worker with a Bastion host for ssh access.
- [System-Assigned Identity](./examples/system-assigned-identity/README.md) - creates a worker
  with a system-assigned identity.
- [User-Assigned Identity](./examples/user-assigned-identity/README.md) - creates a worker with
  a user-assigned identity, and shows how to use that identity to access the worker pool credentials
  via KeyVault secrets.
