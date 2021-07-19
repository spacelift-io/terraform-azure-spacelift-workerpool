# Private Worker with Bastion for SSH

This example shows how to provision a Spacelift private worker using an Azure VMSS, along with
a [Bastion](https://docs.microsoft.com/en-gb/azure/bastion/) host to allow you to connect to
the VM instances. It also uses KeyVault to store the SSH key for connecting to the VM instances,
along with the credentials required for the worker pool to authenticate with Spacelift.

## Usage

To run the example, create a tfvars file with the following variables specified:

```hcl
admin_public_key = "<your-base64-encoded-ssh-public-key>"
admin_private_key = "<your-base64-encoded-ssh-private-key>"
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
