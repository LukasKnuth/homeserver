# Home Server

The FULL configuration of my small RPi (= Raspberry Pi 4B) based server at home.

I'm using the 4GB version to run all of this on a single machine. Everything runs off of a SD Card, no additional hardware required.

The reason this is public is to be a **learning resource**. Thats why it's licensed as GPL-3.0.

## Installation

**Requirements**, this must be installed on your local system:

* [just](https://github.com/casey/just) - To use the local `justfile` for commands
* [Docker](https://www.docker.com/products/docker-desktop/) - to build Nix and NixOS RPi/Container images
* [k3sup](https://github.com/alexellis/k3sup) - to get the `kubeconfig` file from a new installation
* [kubectl](https://kubernetes.io/docs/tasks/tools/) - CLI, setup to interact with the Kubernetes cluster
* [fluxcd](https://fluxcd.io/) - the CLI to setup the K3s cluster with FluxCD

All these tools are referenced in the `justfile` in the root folder of this repository. It contains all important commands (or receipts) needed to work with all aspects of this repository.

Then, run these commands:

1. TODO: build the RPi image
2. TODO: Flash the RPi Image to SD card
3. Insert SD card, boot the system, verify you can connect via SSH
4. `just fetch-kubeconfig <ip>` to download the `kubeconfig` file for connecting via `Kubectl`
  * Tip: Export the `KUBECONFIG` env variable and point it to the downloaded `kubeconfig` file. For example, using [direnv](https://direnv.net/)
5. Verify you can connect via `kubectl cluster-info`
6. `just create-1password-secret 1password-credentials.json`
  * Requires [1Password Connect](https://start.1password.com/integrations/connect)
7. `just create-1password-token <token>`
8. TODO: use fluxcd command to init replication to cluster
9. Wait for the cluster to reconcile. Done :tada:

## Repo Organization

This repository is a mono-repo which contains _everything_ required to setup the home server. This includes:

1. A NixOS configuration for the Linux Image flashed to the SD Card on RPi
  * `host_system/` folder
2. A Nix configuration for a Container Image to perform util tasks in the cluster around backups
  * `utility/` folder
3. All Helm Charts for applications run in the cluster via Kubernetes
  * `charts/` folder
4. The FluxCD cluster configuration for all apps, provisioners and configuration on the cluster
  * `cluster/` folder

## Technology and Reasoning

### Container Orchestrator

I'm using Kubernetes on my personal server. Not full-blown Kubernetes but the much smaller (but still fully compliant) [K3s](https://k3s.io/) distribution.

Do you need Kubernetes? No. Is it necessary for my setup? No. Why then? I have a bunch of (professional) experience with it, it lets me learn more about the system, I like it.

### Passwords/Secrets

Passwords and Secrets are stored in 1Password and only referenced in configuration. The secrets are then fetched and turned into Kubernetes `Secret` resources by the [external-secrets](https://external-secrets.io/) operator.

This additionally requires the [onepassword-connect](https://github.com/1Password/connect) controller running in the cluster to make the actual requests to the 1Password server.

**Pros**
+ I was already using 1Password as my password manager
+ I was already paying for 1Password, so this is free to use

**Cons**
- The connect component isn't really active on GitHub
- The connect component is closed-source, only documentation is available

### Nix and NixOS

I have just recently started looking into [Nix](https://nixos.org/) and the companion project NixOS. Both are efforts to make packages/a whole operating system declarative.

This means mainly that you'll be writing a configuration file and building your system/environment from it. If you want things changed, you change the configuration and rebuild it.

The system also allows a lot of flexibility in configuration, so I can create a fully set up system from a single config file. No more automating Raspberry OS configuration. The built system has SSH enabled, already has my SSH pub-key and all required packages installed and configured.

**Pros**
+ Very flexible and powerful way of creating very custom systems
+ No need for automation with Ansible/Chef, everything is "already there"
+ Many packages are supported, configuration is documented and validated

**Cons**
- Requires a Nix environment to build, which seems to conflict on OS X. Solution: Building in Docker
- The configuration language and the systems concepts have a steep learning curve, even if you're familiar with Linux
- Manual adaption required, most RPi documentation is for Raspberry OS

### FluxCD

We're using ArgoCD at work and I don't like it too much. Flux allows _everything_ to be configured in simple YAML files in a single repository, no configuration is done in any UIs and/or stored somewhere else.

To make up for no UI, I use [k9s](https://k9scli.io/), a Kubernetes client with easy navigation and auto refresh. During deployments, I use it to watch either `Kustomization` resources, or the `HelmRelease` resources. The events on these usually tell you whats wrong if a deployment fails.

**Pros**
+ Well documented, supported and a complete product
+ Everything can be stored in a single place, easily reproduced from a repo
+ No UIs, everything is custom resources

**Cons**
- Helm Charts aren't updated if their version doesn't change. Not immediately obvious
- I haven't been able to do any manual rollback for failing deployments. It's GitOps or die
- Since there is no UI, you gotta know which resources are relevant to watch.

### Helm Charts

Kustomize with patches on normal YAML files is more lightweight, but again I have used Helm before and it's workflow comes more natural to me. At the simplest, it's just a template engine to create YAML files.

My main takeaway here is that YAML is a weird language with many ambiguities, such as unquoted strings or structure via indention. Any system to create/manipulate these files will be complex just because of that. So you're really just choosing your poison, so pick what you like.

**Pros**
+ Widely used, good documentation, many resources available
+ Supported by FluxCD out of the box
+ Available for many other Kubernetes workloads, so we're not using multiple tools for the same thing
+ Natural way to group everything belonging to an app together

**Cons**
- I find the Go templating notation kind of weird
- Helm requires a Controller on the cluster which is a little more heavy-weight
- Some of the Helm documentation doesn't apply when using FluxCD, since it controls your Helm Charts, not you

### Traefik

I like that this is focused and smaller than alternatives such as Nginx. It ships it's own CRDTs which make complex routing easily configurable via YAML files (e.g. as part of a Chart).

**Pros**
+ It gets out of the way, just configure and forget
+ Focused on what I need: Edge Routing and Proxying

**Cons**
- They ship their own CRDTs, not using standard K8s resources