# Private Worker with Autoscaler

This example shows how to provision a Spacelift private worker using an Azure VMSS with the
autoscaler enabled. The autoscaler deploys an Azure Function that monitors the Spacelift worker
pool queue and automatically scales the VMSS up and down based on demand.

## What Gets Created

In addition to the standard worker pool resources (VMSS, VNet, subnet, etc.), the autoscaler
provisions:

- An **Azure Function App** running the Spacelift autoscaler binary
- A **Storage Account** for the Function App package
- An **App Service Plan** (Linux, S1 SKU)
- An **Application Insights** instance for monitoring
- A **Key Vault** for storing the Spacelift API key secret (or uses an existing one)
- **RBAC role assignments** granting the Function App permission to scale the VMSS

## Prerequisites

You need a [Spacelift API key](https://docs.spacelift.io/integrations/api#spacelift-api-key-token)
with permissions to read worker pool information. The autoscaler uses this to query the queue
depth and decide when to scale.

## Usage

This example uses placeholder/dummy values for all secrets (SSH keys, worker pool credentials,
API keys) so it can be used for testing without real Spacelift credentials. Initialize and apply:

```shell
terraform init
terraform apply
```

> **Note:** In production, replace the hardcoded placeholder values in `main.tf` with real
> credentials from your Spacelift account.

## Autoscaler Configuration

The `autoscaling_configuration` block in `main.tf` controls the autoscaler behavior:

| Parameter           | Default        | Description                                                      |
|---------------------|----------------|------------------------------------------------------------------|
| `max_create`        | `1`            | Maximum instances to create in a single autoscaler run           |
| `max_terminate`     | `1`            | Maximum instances to terminate in a single autoscaler run        |
| `scale.min`         | —              | Minimum number of VMSS instances                                 |
| `scale.max`         | `5`            | Maximum number of VMSS instances                                 |
| `schedule_expression` | `0 */5 * * * *` | Azure Functions cron expression for how often the autoscaler runs |
| `version`           | `latest`       | Version of the autoscaler binary to deploy                       |
| `architecture`      | `amd64`        | Instruction set architecture (`amd64` or `arm64`)                |
| `key_vault_id`      | `null`         | Existing Key Vault ID (creates a new one if null)                |
| `scale_down_delay`  | `0`            | Minutes a worker must be registered before eligible for termination |
