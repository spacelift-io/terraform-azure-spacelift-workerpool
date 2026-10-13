# HTTP Long-Poll Missing URL (Negative Test)

This example is a **negative test**: it is expected to fail at plan time.

The module defaults `worker_comms_protocol` to `poll`, and HTTP long-polling requires
`worker_comms_url` so the launcher knows which Spacelift server to poll. This example omits
`worker_comms_url`, so the VMSS resource's precondition rejects the plan:

```
worker_comms_url must be set when worker_comms_protocol is "poll".
```

It is registered in `.spacelift/config.yml` with `negative: true`, so the Spacelift module test
passes only when the plan fails. See the [HTTP long-poll example](../http-long-poll/README.md)
for the working configuration.

## Usage

```shell
terraform init
terraform plan   # expected to fail
```
