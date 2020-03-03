# Tezos Infrastructure

This repository defines machines and resources for the part of the Tezos
infrastructure operated by Serokell OÜ.

All AWS resources are managed by Terraform. Machine configuration is managed
with Nix, and all machines run NixOS.

All necessary programs and dependencies are provided by Nix in `shell.nix`.

## Repository layout

```
.
├── hosts
├── lib
│   └── default.nix
├── main.tf
├── nix
│   ├── default.nix
│   ├── overlays.nix
│   ├── sources.json
│   └── sources.nix
├── nixops-libvirt.nix
├── profiles
│   ├── default.nix
│   ├── mainnet
│   │   └── default.nix
│   ├── ssh-keys.nix
│   └── testnet
│       └── babylon
│           └── default.nix
├── README.md
└── shell.nix

```

* The `hosts` file defines target hosts for `pssh`. See below.
* The `lib` folder contains reusable functions to help with profile management.
* The `main.tf` terraform file contains all cloud resource declarations.
* The `nix` folder defines a local Nix resource pin used in `shell.nix`.
* The `nixops-libvirt.nix` file defines VM deployments for local hacking.
* The `profiles` folder contains Nix expressions to configure each server type.
* The `profiles/ssh-keys.nix` file defines shell accounts and associated SSH keys.
* The `profiles/default.nix` file defines defaults applied to all machines.
* The `shell.nix` file defines a managed shell environment with all necessary
  dependencies to work with this repository.

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

Server configuration files live in the `profiles` folder. `profiles/default.nix`
applies to all servers, and each server config only adds what is necessary for itself.

### Tezos nodes

Tezos nodes are mostly the same, with the exception of the Docker tag they run.
For this reason, the entire config is defined as a parametrized Nix function in
`lib/default.nix`.

### Updating servers

All servers are configured to pull its configuration, rather than have it
pushed. You will find that one of the two Nix channels configured points at this
repository's master branch.

`amazon-init` will configure Nix channels and rebuild the server on boot, which
should not take long, since we use custom AMIs. This will provision SSH users
based on `profiles/ssh-keys.nix`.

Changes are not deployed automatically. After a new commit has been pushed to
the master branch of this repository, you still need to run `nixos-rebuild
switch --upgrade` in order to tell the server to pull the new configuration and
rebuild itself.

This also happens automatically on server boot via the `amazon-init` systemd
unit. This unit will also overwrite any nix channels with the ones provided via
`user_data` by Terraform.

The tool `pssh` will help here:

```
$ pssh -h hosts -o out -e err sudo nixos-rebuild switch --upgrade
```

You can watch the output in another console:

```
$ tail -f {err,out}/<hostname>
```
