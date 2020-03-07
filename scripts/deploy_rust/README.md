# Rust project template

This should set you up for Rust development with Nix.

## Usage

Uses [niv](https://github.com/nmattia/niv) for dependency management.

Run `cargo new` as you would, then copy all these files into the project
folder. Edit `default.nix` to set the Rust channel you want to use. `nix-shell`
will set you up for development.

## Contents

The overlay defined in `nix/default.nix` imports the mozilla Rust overlay and
sets the Rust channel to 1.36.0. Feel free to set this to latest stable, or
nightly, or whatever you want.

Things are also set up for a Diesel project, with a `diesel_cli` derivation in
the overlay (see `nix/pkgs/diesel_cli`).
