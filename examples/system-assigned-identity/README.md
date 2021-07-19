# Private Worker with a System Managed Identity

This example shows how to provision a Spacelift private worker using an Azure VMSS, using a
System-Assigned Managed Identity to grant the workers permission to manage your Azure subscription.

Using a system-assigned managed identity has the slight advantage of simplifying your Terraform
configuration (you don't need to pass Terraform the Application ID of the identity in the
`ARM_CLIENT_ID` variable), but means that you can only grant permissions after the VMSS has
been created.

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
