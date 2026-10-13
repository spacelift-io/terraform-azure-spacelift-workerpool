# HTTP Long-Poll Worker Communication

This example deploys a SaaS worker pool using the module's default HTTP long-poll transport.

The module exports these values before starting the launcher:

```sh
SPACELIFT_WORKER_COMMS_PROTOCOL=poll
SPACELIFT_WORKER_COMMS_URL=<worker_comms_url>
```

`worker_comms_url` is required whenever the protocol is `poll`, and the plan fails without it.
This example uses `https://app.spacelift.io` for EU SaaS. For US-region SaaS, use
`https://app.us.spacelift.io`. For self-hosted and FedRAMP Spacelift, use the base URL provided
for the environment. The companion [HTTP long-poll missing URL](../http-long-poll-missing-url/README.md)
example is a negative test that confirms the plan is rejected when the URL is omitted.

Workers only need outbound HTTPS (port 443) access to the communication URL. Make sure any
Network Security Groups, Azure Firewall rules, or forced-tunnel routes on the worker subnet
allow that traffic.

To temporarily retain the deprecated MQTT transport during migration, set:

```hcl
worker_comms_protocol = "mqtt"
```

## Usage

This example uses placeholder values for all secrets (SSH keys, worker pool credentials) so it
can be used for testing without real Spacelift credentials. Initialize and apply:

```shell
terraform init
terraform apply
```

> **Note:** In production, replace the hardcoded placeholder values in `main.tf` with real
> credentials from your Spacelift account.
