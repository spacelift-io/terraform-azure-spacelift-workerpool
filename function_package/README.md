# Azure Function Package for Spacelift Autoscaler

This directory contains the Azure Function deployment package for the Spacelift worker pool autoscaler.

## Structure

```
function_package/
├── host.json                    # Azure Functions host configuration
├── AutoscalerTimer/
│   └── function.json           # Timer trigger configuration
├── package.sh                  # Script to create deployment package
└── README.md                   # This file
```

## Building the Package

The `package.sh` script creates a deployment-ready zip file containing:

1. The `bootstrap` binary (copied from parent directory)
2. `host.json` (Azure Functions runtime configuration)
3. `AutoscalerTimer/function.json` (Timer trigger definition)

To build the package manually:

```bash
./package.sh
```

This will create `autoscaler-function.zip` in this directory.

## How It Works

### Custom Handler Configuration

The Azure Function uses a [custom handler](https://learn.microsoft.com/en-us/azure/azure-functions/functions-custom-handlers) to run the Go binary:

- **host.json**: Defines the custom handler pointing to the `bootstrap` executable
- **Timer Trigger**: Invokes the function on a schedule defined by `SCHEDULE_EXPRESSION` environment variable

### Binary Execution

When the timer triggers:
1. Azure Functions runtime invokes the custom handler
2. The `bootstrap` binary is executed
3. Binary reads environment variables for configuration
4. Binary performs autoscaling logic and exits

### Environment Variables

The binary requires these environment variables (set in Function App settings):

- `SPACELIFT_API_KEY_ID` - Spacelift API key ID
- `SPACELIFT_API_KEY_SECRET_NAME` - Azure Key Vault secret URL
- `SPACELIFT_API_KEY_ENDPOINT` - Spacelift API endpoint
- `SPACELIFT_WORKER_POOL_ID` - Worker pool ID
- `AUTOSCALING_GROUP_ARN` - Azure VMSS resource ID
- `AUTOSCALING_REGION` - Azure region
- `AUTOSCALING_MAX_KILL` - Max instances to terminate per run
- `AUTOSCALING_MAX_CREATE` - Max instances to create per run
- `AUTOSCALING_SCALE_DOWN_DELAY` - Minutes before worker eligible for termination
- `SCHEDULE_EXPRESSION` - Cron expression for timer trigger

## Deployment

Terraform handles deployment automatically via the `azurerm_linux_function_app` resource. The package is either:

1. **Local mode** (default): Built from the committed `bootstrap` binary
2. **Download mode** (future): Downloaded from a URL

## Notes

- The binary must be Linux x86-64 compatible
- Package size is approximately 54MB (size of the binary)
- Timer trigger must have max concurrency of 1 to prevent overlapping executions
- The binary uses Azure DefaultAzureCredential for authentication (managed identity)
