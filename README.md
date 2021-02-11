# StakerDAO infrastructure

This repository defines machines and resources for the part of the StakerDAO
infrastructure operated by Serokell OÜ.

All AWS resources are managed by Terraform. Machine configuration is managed
with Nix, and all machines run NixOS.

All necessary programs and dependencies are provided by Nix in `shell.nix`.

## Repository layout

- [./terraform](./terraform) contains terraform expressions used to deploy
  all EC2 servers and Route53 zones&records for stakerdao.serokell.team

- [./common.nix](./common.nix) provides common NixOS configuration defaults
  for all servers

- [./profiles](./profiles) contains NixOS configuration "profiles": common
  values and defaults for various types of servers

- [./servers](./servers) contains NixOS server descriptions. Usually just
  imports a profile and changes the default values to specific ones

- [./flake.nix](./flake.nix) defines repository dependencies, passes them
  down to `servers` and builds the final NixOS systems to be deployed. Also
  defines a `devShell` containing packages used to deploy this repo and a
  `deploy` attribute which describes how to deploy NixOS systems to servers.

- `./flake.lock` is a lockfile containing dependency pins (git revisions)
- `./default.nix` and `./shell.nix` are for pre-flake nix compatibility.

## Usage

First, make sure you have [Nix](https://nixos.org/nix/) installed.

Then, open a managed shell: `nix-shell`. This will drop you in a Bash shell with
all necessary tools and dependencies loaded.

### Vault
[Vault](https://www.vaultproject.io/) is a secrets management service
from Hashicorp. We use it to store secrets that can be used to access
our code. Serokell employees can use `vault login -method=oidc` to
generate the neccesary token.

### Terraform

Terraform is an Infrastructure as Code tool from Hashicorp. Read more
[here](https://www.terraform.io/).

The first time you use it, you need to run `terraform init`. This will
initialize local state and download any missing plugins.

Terraform resources are declared in `main.tf`.

Your main workhorse will be `terraform apply`, which will print a diff view of
any resource changes, and ask you whether you want to commit them. Please read
this output carefully, as Terraform will not hesitate to nuke anything it thinks
needs nuking.

### Server profiles

Server configuration files live in the [./servers](./servers) folder. Things common
to all servers are in [./common.nix](./common.nix)

### Agora

There are two agora servers in this configuration: staging and production.
Profile for both of them is [./profiles/agora.nix](./profiles/agora.nix). The
production server also defines one vault secret, the approle for which
needs to be deployed manually (for now). Address for the Agora service
matches FQDN, the address for TZIP browser is in the table below.

| **Server**       | **FQDN**                  | **TZIP browser URL**     |
|------------------|---------------------------|--------------------------|
| agora-staging    | agora.tezos.serokell.team | tzip.tezos.serokell.team |
| agora-production | www.tezosagora.org        | tzip.tezosagora.org      |

### Deploying or updating

- Enter `nix-shell` or `nix develop`
  + Run `terraform init $dir && terraform apply $dir` where `$dir` is either staging or production
  + Run `deploy .#$server` where `$server` is the name of the server you're deploying or updating
  + If applicable, copy the vault approle environment to `/root/vault-secrets.env.d` (FIXME: automate this)
