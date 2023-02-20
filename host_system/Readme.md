# NixOS RaspberryPi Image configuration

This is a NixOS configuration for creating a Host system running on a RaspberryPi 4B. This is what I use to run the K3s cluster which runs all applications.

There are two interesting files here and a "GitOps like" workflow for keeping the configuration in this directory up-to-date with what is running on my actual machine.

## `configuration.nix`

This is the actual NixOS configuration. To customize it, use the variables defined in the initial `let`-block:

* `pw_hash` is created with `mkpasswd -m sha512`
* `ssh_pub_keys` is a list of all **public** keys for passwordless SSH
* Most network configuration is statically setup in this file. Change the variables as appropriate for your circumstances.

The configuration itself does few noteworthy things, most of which are explained with comments in-line.

What is noteworthy is that the firewall configuration resides in the configuration file as well. This means that new services which use irregular ports must first be whitelisted there.

## `sdImage.nix`

Contains the minimal SD Card setup and imports the `configuration.nix` file, which is the _actual_ configuration of the system.

The result is a full flashable SD Card Image which can be flashed for example using the [official Raspberry Pi Imager](https://www.raspberrypi.com/software/) or `dd`.

It's **important** to mention that the resulting system in the image is built to the specifications in the `configuration.nix`-file, but does NOT contain the file itself. This means that running `nixos-rebuild` on the resulting system will not find a configuration to build. This is addressed in the configuration chapter of this file.

## Configuration from Git

To enable a "GitOps like" workflow where the configuration on the host system is kept up-to-date in this Git repository, I follow this simple template:

After first boot, `git clone` this repo to a world-readable folder. To enable this in a somewhat anonymous, readonly fashion, we can clone the repository with a [fine grained Access-Tokens](https://github.com/settings/personal-access-tokens/new) in the URL:

```bash
https://oauth2:<token>@github.com/LukasKnuth/homeserver.git
```

Next, create this minimal configuration under `/etc/nixos/configuration.nix`:

```nix
{ ... }:
{
  imports = [ /path/to/git/repo/host_system/configuration.nix ];
}
```

This simply imports the `configuration.nix` file from this folder. Then, we can run `nixos-rebuild` as expected.

**Important:** When I need to make changes to the configuration, I DONT change the `configuration.nix` file on the host system! Instead, I make the changes on my computer, commit and push them via git, SSH into the host machine and `git pull && nixos-rebuild`.

This way, the live configuration on the host and what's stored in this repository don't drift and I always have a copy of my current config to recreate the system quickly.
