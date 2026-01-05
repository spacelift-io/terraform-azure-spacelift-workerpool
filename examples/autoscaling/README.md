# Autoscaling Example

This example demonstrates how to deploy a Spacelift worker pool on Azure with autoscaling enabled.

## Overview

The autoscaling feature uses an Azure Function that runs periodically (default: every 5 minutes) to monitor the Spacelift worker pool queue and automatically scale the VMSS capacity up or down based on demand.

## How It Works

1. **Scale Up**: When there are more schedulable runs than idle workers, the autoscaler increases the VMSS capacity
2. **Scale Down**: When there are excess idle workers, the autoscaler gracefully drains and terminates instances
3. **Stray Instance Cleanup**: Instances running for >10 minutes that aren't registered with Spacelift are automatically terminated

## Prerequisites

1. Azure subscription with appropriate permissions
2. Spacelift account and worker pool created
3. Spacelift API key with permissions to:
   - Query worker pool metrics
   - List and manage workers
   - Drain workers

## Creating a Spacelift API Key

1. Log into your Spacelift account
2. Navigate to Settings → API Keys
3. Create a new API key with the following permissions:
   - `worker_pool:read`
   - `worker:read`
   - `worker:write` (for draining)
4. Save the Key ID and Secret for use in this example

## Usage

1. Accept the Spacelift Marketplace image terms (if using the default image):
   ```bash
   az vm image terms accept \
     --publisher "spaceliftinc1625499025476" \
     --offer "spacelift_worker" \
     --plan "ubuntu_20_04"
   ```

2. Create a `terraform.tfvars` file:
   ```hcl
   worker_pool_id           = "your-worker-pool-id"
   worker_pool_config       = "your-worker-pool-token"
   worker_pool_private_key  = "your-private-key"
   admin_password           = "YourSecurePassword123!"
   spacelift_api_key_id     = "your-api-key-id"
   spacelift_api_key_secret = "your-api-key-secret"
   ```

3. Initialize and apply:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Configuration Options

### Autoscaling Parameters

- `schedule_expression`: Cron expression for how often to run the autoscaler (default: every 5 minutes)
- `max_create`: Maximum number of instances to add per autoscaling cycle (default: 1)
- `max_terminate`: Maximum number of instances to remove per autoscaling cycle (default: 1)
- `scale_down_delay`: Minutes to wait before a new instance is eligible for termination (default: 5)
- `min_idle_workers`: Minimum number of idle workers to maintain (default: 0)

### Capacity Constraints

Set the min/max capacity using tags on the VMSS:

```hcl
tags = {
  MinCapacity = "1"   # Minimum VMSS instances
  MaxCapacity = "10"  # Maximum VMSS instances
}
```

## Monitoring

The autoscaler includes Application Insights for monitoring:

1. View the Function App logs in the Azure Portal
2. Check Application Insights for metrics and traces
3. Monitor VMSS scaling operations in the Activity Log

### Key Metrics to Monitor

- Function execution time
- Scaling decisions (scale up/down/none)
- Worker pool queue length
- Idle worker count

## Troubleshooting

### Autoscaler not scaling

1. Check the Function App logs for errors
2. Verify the Spacelift API credentials are correct
3. Ensure the Managed Identity has permissions on the VMSS
4. Check that the worker pool ID is correct

### Workers not registering

1. Verify the worker pool configuration and private key
2. Check VMSS instance logs at `/var/log/spacelift/`
3. Ensure network connectivity to Spacelift

### Scale down too aggressive

Adjust these parameters:
- Increase `scale_down_delay` to wait longer before terminating new instances
- Decrease `max_terminate` to remove fewer instances per cycle
- Increase `min_idle_workers` to maintain more buffer capacity

## Cost Optimization

The autoscaling feature helps optimize costs by:

1. **Scaling down idle workers** during low activity periods
2. **Maintaining minimum capacity** only when needed
3. **Using Consumption plan** for the Function App (pay-per-execution)

Estimated additional cost for autoscaling: ~$1-5/month for the Function App and Application Insights.

## Security Considerations

1. **API Keys**: Store Spacelift API credentials securely (use Azure Key Vault in production)
2. **Managed Identity**: The Function App uses Managed Identity to access Azure resources
3. **Network Security**: Consider using VNet integration for the Function App
4. **RBAC**: The autoscaler only has permissions on the specific VMSS

## Next Steps

- Set up alerts for autoscaling failures
- Integrate with Azure Monitor for centralized logging
- Configure custom scaling rules based on your workload patterns
- Use Azure Key Vault to store sensitive credentials
