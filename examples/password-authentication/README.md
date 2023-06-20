# Private Worker with a User Assigned Identity

This example shows how to provision a Spacelift private worker using an Azure VMSS, using a
User-Assigned Managed Identity to grant the workers permission to manage your Azure subscription.
It also creates a KeyVault to store the worker pool credentials in, and uses the user-assigned
identity to grant the VMSS permission to those secrets.

Using a user-assigned managed identity gives you more control than using a [system-assigned identity](../system-assigned-identity/README.md),
allowing you to do things like provision secrets in KeyVault and grant the correct permissions
before your scale set is created.

**NOTES:**

- When using a user-assigned identity, you need to pass the identity's `client_id`
  to the Terraform provider via the `ARM_CLIENT_ID` environment variable when following the
  [authentication instructions](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/managed_service_identity).
- Although we're using KeyVault to store the secrets, please note that the Azure RM provider
  stores the secret values in plain text in your state, so the usual warnings about treating
  your state as a secret apply.

## Usage

To run the example, create a tfvars file with the following variables specified:

```hcl
admin_public_key = "<your-base64-encoded-ssh-public-key>"
worker_pool_config = "<your-worker-pool-config>"
worker_pool_private_key = "<your-worker-pool-private-key>"
worker_pool_id = "<your-worker-pool-id>"
location = "West Europe"
```

Now just initialise Terraform, and run an apply:

```shell
terraform init
terraform apply -var-file myvars.tfvars
```
