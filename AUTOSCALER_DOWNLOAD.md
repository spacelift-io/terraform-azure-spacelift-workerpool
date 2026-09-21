# Autoscaler Binary Download Feature

This module now supports downloading the Spacelift autoscaler binary from GitHub releases instead of requiring it to be committed to the repository.

## Overview

The autoscaler can now be sourced in two ways:

1. **Local Mode** - Use a pre-existing binary in the repository
2. **Download Mode** - Download from [spacelift-io/ec2-workerpool-autoscaler releases](https://github.com/spacelift-io/ec2-workerpool-autoscaler/releases)

## Configuration

### Download Mode (Recommended)

```hcl
module "spacelift_workerpool" {
  source = "./terraform-azure-spacelift-workerpool"

  autoscaling_enabled = true

  autoscaling_configuration = {
    binary_source       = "download"
    binary_version      = "v2.1.0"  # or "latest"
    binary_architecture = "x86_64"

    # Other autoscaling settings...
    schedule_expression   = "0 */5 * * * *"
    max_create            = 1
    max_terminate         = 1
    scale_down_delay      = 0
    capacity_sanity_check = 10
  }

  # Required for autoscaling
  spacelift_api_key_id     = var.spacelift_api_key_id
  spacelift_api_key_secret = var.spacelift_api_key_secret
  spacelift_api_endpoint   = "https://mycompany.app.spacelift.io"
}
```

### Local Mode

```hcl
autoscaling_configuration = {
  binary_source = "local"
  # binary must exist at ./bootstrap before terraform apply
}
```

## Binary Version Options

### Pinned Version (Recommended for Production)

```hcl
binary_version = "v2.1.0"
```

- Downloads a specific version
- Reproducible deployments
- Only re-downloads if version changes
- Best for production environments

### Latest Version (Development/Testing)

```hcl
binary_version = "latest"
```

- Downloads the newest release
- Re-downloads on every `terraform apply`
- Useful for testing new features
- May introduce breaking changes

## How It Works

1. **Download Phase** - When `binary_source = "download"`:
   - Terraform runs [download.sh](download.sh) script during `terraform apply`
   - Script fetches the binary from GitHub releases
   - Binary is saved to `./bootstrap` in the module directory

2. **Package Phase**:
   - [function_package/package.sh](function_package/package.sh) packages the binary
   - Creates `autoscaler-function.zip` with Azure Function structure
   - Includes `host.json` and `AutoscalerTimer/function.json`

3. **Deploy Phase**:
   - Terraform uploads zip to Azure Blob Storage
   - Azure Function App deploys from blob storage
   - Function executes on timer schedule

## Architecture Support

The binary is available for two architectures:

- `x86_64` (amd64) - Default, works with most Azure Function plans
- `arm64` - For ARM-based function plans

## GitHub API Rate Limits

The download script uses the GitHub API to fetch release information:

- **Unauthenticated**: 60 requests/hour
- **Authenticated**: 5000 requests/hour (set `GITHUB_TOKEN` environment variable)

For CI/CD pipelines:

```bash
export GITHUB_TOKEN=ghp_yourtoken
terraform apply
```

## Manual Download

You can manually download and package:

```bash
# Download binary
./download.sh v2.1.0 x86_64 .

# Create package
cd function_package
./package.sh
```

## Migration from Local to Download Mode

1. Update your Terraform configuration:
   ```hcl
   autoscaling_configuration = {
     binary_source = "download"  # Changed from "local"
     binary_version = "v2.1.0"
   }
   ```

2. Remove the committed bootstrap binary (optional):
   ```bash
   git rm bootstrap
   git commit -m "Use download mode for autoscaler binary"
   ```

3. Apply the changes:
   ```bash
   terraform apply
   ```

## Files

- [download.sh](download.sh) - Downloads binary from GitHub releases
- [function_package/package.sh](function_package/package.sh) - Creates deployment package
- [autoscaler.tf](autoscaler.tf) - Terraform resources for autoscaling
- [.gitignore](.gitignore) - Excludes bootstrap and packages from git

## Troubleshooting

### Rate Limit Exceeded

```
GitHub API rate limit exceeded, cannot find latest version
```

**Solution**: Set `GITHUB_TOKEN` or pin to a specific version (doesn't use GitHub API)

### Binary Not Found

```
Error: bootstrap binary not found at ./bootstrap
```

**Solution**: Check download script executed successfully. Run manually:
```bash
./download.sh latest x86_64 .
```

### Architecture Mismatch

If the function fails to start, verify architecture matches your service plan:

```hcl
binary_architecture = "x86_64"  # Most common
```

## Security Notes

- Binary is downloaded from official Spacelift GitHub releases
- The download script verifies the binary exists after extraction
- Binary runs with Azure Function App managed identity (no credentials in code)
- All secrets are stored in Azure Key Vault
