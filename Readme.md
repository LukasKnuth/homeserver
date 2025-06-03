# Home Server

The FULL configuration of my small RPi (= Raspberry Pi 4B) based server at home.

I'm using the 4GB version to run all of this on a single machine. Everything runs off of a SD Card, no additional hardware required.

The reason this is public is to be a **learning resource**. That's why it's licensed as GPL-3.0.

## Installation

**Requirements**, this must be installed on your local system:

* [just](https://github.com/casey/just) - To use the local `justfile` for commands
* [direnv](https://github.com/direnv/direnv) - To automatically export ENV variables
* [talosctl](https://www.talos.dev/latest/talos-guides/install/talosctl/) - To set up the cluster nodes
* [kubectl](https://kubernetes.io/docs/tasks/tools/) // [k9s](https://k9scli.io/) - To interact with the Kubernetes cluster
* [terraform](https://www.terraform.io/) - To deploy workloads to the cluster

All these tools are referenced in the `justfile` in the root folder of this repository. It contains all important commands (or receipts) needed to work with all aspects of this repository.

Then, run these commands:

0. Flash the [Talos Metal RPi image](https://www.talos.dev/latest/talos-guides/install/single-board-computers/rpi_generic/) to an SD Card and insert it
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
3. Any scripts and docker images uses to maintain the server
  * `maintenance/` folder

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

Instead of a "real" database, I restrict myself to SQLite. This means I don't have to run, configure and monitor a database on this server. The drawback is that I can't run applications that _require_ a real database. Fortunately, most database abstractions support SQLite, so most apps built on top of popular frameworks get SQLite support for free.

I don't run regular backup jobs. Instead, I use [Litestream](https://litestream.io/) for continuous replication of the SQLite databases to a NAS server on my network. _That_ server then backs up to the Cloud on a schedule. This gives both strong durability and fast backup and restore operations.

Because restore operations are fast and backups continuous, I only use ephemeral storage on the server, meaning: When a Pod is deleted (for a restart or redeployment) it looses _all_ its local data. When the new Pod is then started, it first restores from the latest backup and then starts the application and continuous replication again.

**Pros**
+ There is no data locality - if a workload is scheduled to a new Node, it will restore the data from the backup to its local ephemeral storage
+ Very limited chance to lose any data because replication is continuous
+ Verifying backup integrity is easy with `litestream restore` and `PRAGMA integrity_check`

**Cons**
- There is a theoretical chance that a high throughput application accumulates a large WAL which isn't fully replicated yet when it is shut down. Since the data is ephemeral, Litestream won't have a chance to "catch up" once it's restarted.
  - I can live with this. Most applications I need are user-interaction driven, so their throughput is comparably low.

## History

### Changing from NixOS/k3s to Talos Linux

In my previous server setup, I created a custom NixOS image to be flashed onto the SD Card. It came with [K3s](https://k3s.io) to run the Kubernetes workloads. It was configured with the absolute minimum to run on my Raspberry Pi.

This served me **very well** for two years. It really was "deploy and forget" - my server ran for 438 days uninterrupted until I had to shut it down to physically move it.

Talos OS does many things that NixOS does as well (namely: declarative configuration of the entire system) but it is even more focused on simply running Kubernetes - and that makes it even simpler.

Where NixOS would have allowed me far more flexibility, I never needed it. So I went with the even simpler option.

### Changing from FluxCD/Helm to Terraform

YAML for Kubernetes manifests is terrible. Go template language for generating YAML is also terrible. So I looked into other configuration languages that would be more expressive (and not whitespace sensitive) and then _compile_ to YAML.

Helms management of CRDs did not easily allow me to update them. When restoring the cluster from manifests, there would be nasty dependencies on order of execution which weren't solved by Helm. Most Helm charts also added more _stuff_ to my cluster than I was comfortable with or able to understand.

FluxCD enabled GitOps to deploy workloads and configuration to the cluster automatically on merge worked well, but since it's only a single person making changes, it was overblown. All I needed was a way to say "I want all of this in here".

All of these technologies _insist_ on adding more _stuff_ to your cluster. Usually a handful of CRDs to configure it and an Operator Pod to make the actual changes in the cluster. Resources on my Raspberry Pi are scarce, I'd rather spent them on useful applications than live Cloud Native overhead.

A non-whitespace config language. Dependency resolution. Drift detection. Terraform does all that. It solves all my gripes and is a lot simpler.

