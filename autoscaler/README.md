# Spacelift Azure Worker Pool Autoscaler

A Go-based autoscaler for Spacelift worker pools running on Azure Virtual Machine Scale Sets (VMSS).

## Overview

This autoscaler is an Azure Functions implementation that monitors Spacelift worker pool metrics and automatically scales the VMSS capacity based on queue demand. It's designed to run periodically (default: every 5 minutes) and makes intelligent scaling decisions to optimize resource utilization.

## Architecture

The autoscaler is implemented as an Azure Function with a custom Go handler that:

1. Queries the Spacelift API for worker pool metrics
2. Analyzes current VMSS capacity and instance state
3. Makes scaling decisions based on configured rules
4. Gracefully drains workers before termination
5. Handles stray instances (not registered with Spacelift)

## Key Features

- **Queue-based scaling**: Scales based on schedulable runs vs idle workers
- **Graceful draining**: Workers are drained before instance termination
- **Stray instance cleanup**: Automatically removes instances not registered after 10 minutes
- **Configurable limits**: Control max scale-up/down per cycle
- **Cool-down periods**: Prevent thrashing with configurable delays
- **Managed Identity**: Secure authentication using Azure Managed Identity
- **Monitoring**: Built-in Application Insights integration

## Building

### Prerequisites

- Go 1.21 or later
- Make (optional, for using Makefile)

### Build Commands

```bash
# Build for Azure (Linux)
make build

# Build for local testing
make build-local

# Create deployment package
make package

# Run tests
make test

# Install dependencies
make deps
```

### Manual Build

```bash
# For Azure Functions (Linux)
GOOS=linux GOARCH=amd64 go build -o autoscaler ./cmd/autoscaler

# Create deployment package
zip -r deploy.zip autoscaler host.json api/
```

## Configuration

The autoscaler is configured via environment variables (set by Terraform):

### Required Environment Variables

| Variable | Description |
|----------|-------------|
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID |
| `VMSS_RESOURCE_GROUP` | Resource group containing the VMSS |
| `VMSS_NAME` | Name of the VMSS |
| `SPACELIFT_API_ENDPOINT` | Spacelift API endpoint URL |
| `SPACELIFT_API_KEY_ID` | Spacelift API key ID |
| `SPACELIFT_API_KEY_SECRET` | Spacelift API key secret |
| `SPACELIFT_WORKER_POOL_ID` | Spacelift worker pool ID |

### Optional Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SCHEDULE_EXPRESSION` | Cron expression for execution | `0 */5 * * * *` |
| `MAX_CREATE` | Max instances to add per cycle | `1` |
| `MAX_TERMINATE` | Max instances to remove per cycle | `1` |
| `SCALE_DOWN_DELAY` | Minutes before instance eligible for termination | `5` |
| `MIN_IDLE_WORKERS` | Minimum idle workers to maintain | `0` |

## Scaling Logic

### Scale Up Decision

```
IF (schedulable_runs > idle_workers + min_idle_workers) THEN
  scale_up_by = MIN(schedulable_runs - idle_workers, max_create)
  target_capacity = MIN(current_capacity + scale_up_by, max_capacity)
```

### Scale Down Decision

```
IF (idle_workers > min_idle_workers) THEN
  scale_down_by = MIN(idle_workers - min_idle_workers, max_terminate)
  target_capacity = MAX(current_capacity - scale_down_by, min_capacity)
```

### Stray Instance Handling

An instance is considered "stray" if:
- It has been running for more than 10 minutes
- It is not registered with the Spacelift worker pool

Stray instances are automatically terminated (max 1 per cycle).

## Deployment

### Via Terraform (Recommended)

The Terraform module handles all infrastructure setup. You just need to:

1. Build and package the autoscaler:
   ```bash
   cd autoscaler
   make package
   ```

2. Deploy using Azure CLI:
   ```bash
   az functionapp deployment source config-zip \
     -g <resource-group-name> \
     -n <function-app-name> \
     --src deploy.zip
   ```

### Manual Deployment

1. Create the deployment package:
   ```bash
   make package
   ```

2. Upload to Azure Function App:
   ```bash
   az functionapp deployment source config-zip \
     --resource-group <resource-group> \
     --name <function-app-name> \
     --src deploy.zip
   ```

## Testing Locally

To test the autoscaler locally:

1. Set required environment variables:
   ```bash
   export AZURE_SUBSCRIPTION_ID="your-subscription-id"
   export VMSS_RESOURCE_GROUP="your-rg"
   export VMSS_NAME="your-vmss"
   export SPACELIFT_API_ENDPOINT="https://your-account.app.spacelift.io"
   export SPACELIFT_API_KEY_ID="your-key-id"
   export SPACELIFT_API_KEY_SECRET="your-key-secret"
   export SPACELIFT_WORKER_POOL_ID="your-pool-id"
   ```

2. Authenticate with Azure:
   ```bash
   az login
   ```

3. Run the autoscaler:
   ```bash
   make run-local
   ```

4. Test the endpoint:
   ```bash
   curl -X POST http://localhost:8080/api/autoscaler
   ```

## Monitoring

### Application Insights

The autoscaler logs all operations to Application Insights:

- Scaling decisions (up/down/none)
- Instance terminations
- Worker draining operations
- Errors and warnings

### Key Metrics

Monitor these in Application Insights:

- **Execution time**: Should be <30 seconds typically
- **Scaling frequency**: Number of scale up/down operations
- **Error rate**: Should be near zero
- **Stray instances**: Number of stray instances found

### Example Queries

```kusto
// Recent autoscaler executions
traces
| where timestamp > ago(1h)
| where message contains "Autoscaler"
| order by timestamp desc

// Scaling operations
traces
| where timestamp > ago(24h)
| where message contains "Scaling"
| summarize count() by bin(timestamp, 1h)
```

## Troubleshooting

### Autoscaler not executing

1. Check Function App status in Azure Portal
2. Verify timer trigger is enabled
3. Check Application Insights for errors
4. Ensure Managed Identity has proper permissions

### Not scaling as expected

1. Review autoscaler logs in Application Insights
2. Verify Spacelift API credentials
3. Check worker pool metrics in Spacelift UI
4. Ensure VMSS tags for MinCapacity/MaxCapacity are set

### Permission errors

The Managed Identity needs:
- `Virtual Machine Contributor` role on the VMSS
- `Reader` role on the Resource Group

Verify with:
```bash
az role assignment list --assignee <managed-identity-principal-id>
```

## Development

### Project Structure

```
autoscaler/
├── cmd/
│   └── autoscaler/
│       └── main.go           # Entry point and HTTP handler
├── internal/
│   ├── spacelift/
│   │   └── client.go         # Spacelift API client
│   └── vmss/
│       └── manager.go        # Azure VMSS management
├── api/
│   └── autoscaler/
│       └── function.json     # Function trigger configuration
├── host.json                 # Function App configuration
├── go.mod                    # Go dependencies
├── Makefile                  # Build automation
└── README.md                 # This file
```

### Adding Features

1. Update the scaling logic in `cmd/autoscaler/main.go`
2. Add new VMSS operations in `internal/vmss/manager.go`
3. Add new Spacelift API calls in `internal/spacelift/client.go`
4. Add tests for new functionality
5. Update documentation

### Testing

```bash
# Run all tests
make test

# Run with coverage
go test -cover ./...

# Run specific package tests
go test ./internal/spacelift
```

## Security Considerations

1. **API Credentials**: Stored as environment variables, consider using Azure Key Vault
2. **Managed Identity**: Uses system-assigned identity for Azure authentication
3. **RBAC**: Minimal permissions (only VMSS access)
4. **Network**: Consider VNet integration for Function App
5. **Secrets**: Never log API keys or secrets

## Performance

- **Execution time**: Typically 5-15 seconds
- **Memory usage**: ~50-100 MB
- **Cold start**: ~2-3 seconds on Consumption plan
- **Concurrency**: Should be 1 (prevent race conditions)

## Known Limitations

1. VMSS instance creation time info not available from Azure API (uses current time as fallback)
2. Requires specific instance deletion (needs VirtualMachineScaleSetVMsClient implementation)
3. Capacity constraints read from VMSS tags (not autoscale settings)

## Contributing

When contributing to this autoscaler:

1. Follow Go best practices and conventions
2. Add tests for new functionality
3. Update documentation
4. Ensure backward compatibility
5. Test with a real VMSS before submitting

## License

Same as the parent terraform-azure-spacelift-workerpool module.

## Support

For issues or questions:
1. Check the [main module README](../README.md)
2. Review the [autoscaling example](../examples/autoscaling/README.md)
3. Open an issue on the repository
