# StakerDAO Infrastructure Code

This repository describes and configures the AWS infrastructure that runs the
StakerDAO cluster, currently two machines:

* Staging at `agora-staging.stakerdao.serokell.team`
* Production at `agora.stakerdao.serokell.team`

## Terraform

There's a single cluster, defined in `terraform/main.tf`.

All terraform commands are to be run in the `terraform` folder.

Your AWS credential profile should be called `stakerdao`.

Run `terraform init` once to install the plugins and initialize local state.

Check your changes with `terraform plan`, and commit them with `terraform apply`.

## Deployment

Deployment is handled by `scripts/deploy.sh`, usually from CI. The system
closure is built in CI, then pushed and activated on the target server. Nothing
is built or evaluated on the target.

Two separate closures are necessary for the server to function: the system
closure, and the agora service closure. The script handles both.

The system closure is described in this repository. The agora closure is
defined in the `stakerdao-agora` repository. This allows to deploy agora
updates independently from system updates.

**The service config is defined via the `agora` module in this repository, and is
part of the system closure. Thus, config changes require a system closure
update.**

The only bit of necessary state on the server is a set of Vault credentials in
`/root/vault-secrets.env.d/agora`. See below.

## Secrets

All secrets are stored in Vault.

Two AppRole policies manage access to runtime secrets: `stakerdao-agora` and
`stakerdao-agora-staging`. The `vault-get-approle-env.sh` script in
`serokell-profiles` will give you the correct format.

Run as such:

    scripts/vault-get-approle-env.sh <AppRole name>

And paste the output in `/root/vault-secrets.env.d/agora`.

The one deploy-time secret, an SSH key that allows access to the `buildkite`
user on target machines, is only accessible to the `stakerdao-infra` buildkite
pipeline.
