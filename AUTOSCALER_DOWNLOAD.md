# Autoscaler Release Download

The module downloads the Azure Function build of the Spacelift worker pool
autoscaler from the
[`ec2-workerpool-autoscaler` releases](https://github.com/spacelift-io/ec2-workerpool-autoscaler/releases).

## Version Selection

Configure the release through `autoscaling_configuration.version`:

```hcl
autoscaling_configuration = {
  version      = "stable"
  architecture = "amd64"

  scale = {
    min = 1
    max = 5
  }
}
```

Supported values are:

- `stable` (default): uses v3.0.2, the release pinned by this module.
- `latest`: resolves the latest GitHub release to a concrete tag during the
  Terraform run.
- A release tag such as `v3.0.0`: deploys that exact release.

`amd64` and `arm64` are the supported architectures.

## Latest Release Authentication

Resolving `latest` uses the GitHub Releases API. Unauthenticated requests are
subject to GitHub's lower API rate limit. Set `GITHUB_TOKEN` in the Terraform
runner environment to authenticate the request:

```shell
export GITHUB_TOKEN="<token>"
terraform apply
```

Provide the token as a sensitive environment variable rather than hardcoding it
in the Terraform configuration.

## Deployment Flow

1. Terraform resolves `stable`, `latest`, or the configured release tag.
2. During apply, Terraform downloads the matching
   `ec2-workerpool-autoscaler_azurefunc_linux_<architecture>.zip` asset.
3. The module packages the binary with the Azure Functions `host.json` and
   timer-trigger configuration.
4. Terraform uploads the deterministic package to Azure Blob Storage and
   configures the Function App to run from that package.

The concrete release tag, architecture, and packaging file hashes determine the
deployment package name. A new package is created only when one of those inputs
changes, avoiding perpetual plan drift when `latest` still points to the same
release.

## Runner Requirements

The Terraform runner must provide:

- `curl`
- `unzip`
- `python3`
- A POSIX-compatible shell
