# Home Server

The FULL configuration of my small RPi (= Raspberry Pi 4B) based server at home.

I'm using the 4GB version to run all of this on a single machine. Everything runs off of a SD Card, no additional hardware required.

The reason this is public is to be a **learning resource**. That's why it's licensed as GPL-3.0.

## Installation

**Requirements**, this must be installed on your local system:

* [just](https://github.com/casey/just) - To use the local `justfile` for commands
* [direnv](https://github.com/direnv/direnv) - To automatically export ENV variables
* [talosctl](https://www.talos.dev/v1.7/talos-guides/install/talosctl/) - To set up the cluster nodes
* [kubectl](https://kubernetes.io/docs/tasks/tools/) // [k9s](https://k9scli.io/) - To interact with the Kubernetes cluster
* [terraform](https://www.terraform.io/) - To deploy workloads to the cluster

All these tools are referenced in the `justfile` in the root folder of this repository. It contains all important commands (or receipts) needed to work with all aspects of this repository.

Then, run these commands:

0. Flash the [Talos Metal RPi image](https://www.talos.dev/v1.7/talos-guides/install/single-board-computers/rpi_generic/) to an SD Card and insert it
1. Review `.envrc` and adapt it to your situation
2. **Once** generate Talos secrets `just gen-secrets`
  * Save this file somewhere and keep it secret
3. Create the Node configuration `just gen-config @talos/patches/rpi4-controlplane.yaml`
4. Apply the Node configuration `just apply-config <ip> insecure`
5. Update the local `talosctl` file `just update-config <ip>`
6. Bootstrap etcd `just bootstrap <ip>`
7. Download local `kubeconfig` with `just kubeconfig`
8. Deploy workloads `just deploy`

## Repo Organization

This repository is a mono-repo which contains _everything_ required to setup the home server. This includes:

1. The configuration patches to Talos Linux default config (version 1.7)
  * `talos/` folder
2. All workload deployments for Kubernetes via Terraform
  * `deploy/` folder

## Technology and Reasoning

> [!NOTE]
> My opinions on technology choices have changed over time. I maintain a [history](#history) with reasons further down.

### Container Orchestrator

I'm using Kubernetes on my personal server. Do you need Kubernetes? No. Is it necessary for my setup? No. Why then? I have a bunch of (professional) experience with it, it lets me learn more about the system, I like it.

To make things simpler, I use [Talos Linux](https://talos.dev) as the host operating system, which is made to just run Kubernetes on bare metal. It has secure defaults and makes installation and configuration simple and declarative.

Also, to make the cluster simpler, I restrict myself to the following:

* NO custom resource definitions - They create ordering dependencies and for my needs, standard kubernetes ships with everything
* NO Helm charts - Helm feels too complicated and not powerful enough at the same time. Most deployments can also be simplified for my specific needs and I like to know what I'm running. If needed, I manually translate external charts to HCL files

### Passwords/Secrets

Where possible, the infra that requires authentication/authorization is set up via Terraform and the secrets are directly passed into the deployments that use them. This eliminates the need to store them somewhere.

> [!IMPORTANT]
> The secrets are still in the Terraform state file, in plain text! Choose a backend that is secured from public access.

**Pros**
+ No need to have a secret store
+ No need to write them down and keep them up-to-date

**Cons**
- Remember to keep your state file secure!

### CI/CD

I find most CI/CD solutions out there too complex for the Job. Especially for something as small as a single node homeserver.

All I need is a way to apply all workloads to the cluster, make modifications/additions where needed and delete anything I have removed from my configuration. Terraform does just that. I simply run it from my dev machine.

**Pros**
+ No more writing YAML
+ No more writing Go Template expressions
+ Does drift detection
+ Nothing to run _inside_ the cluster

**Cons**
- No live controller that enforces GitOps

### Ingress

I use [Traefik](https://doc.traefik.io/traefik/). It's focused and smaller than alternatives such as Nginx. It works with the standard `Ingress` resources and is easy to configure.

**Pros**
+ It gets out of the way, just configure and forget
+ Focused on what I need: Edge Routing and Proxying

**Cons**
- The documentation is sometimes either lacking or not well organized

### Persistent Storage

SQLite with Litestream replication.

TODO

## History

### Changing from NixOS/k3s to Talos Linux

asd

### Changing from FluxCD to Terraform

asd
