# Talos Linux

We use [Talos Linux](https://talos.dev) to run the actual Kubernetes Cluster on the hardware.

## How to Setup

Talos Linux is not an interactively configured system - we create a configuration file that describes how a Node should be configured and then initialize it with said configuration.

Instead of building the full config file though, we create a series of patches that manipulate the default config to our liking. Some configuration is applied to all Nodes in the cluster (such as DNS and Virtual IP settings) while other configuration is meant to be specific to a Node.

Check the `Justfile` in the repo to tell the difference between the two.

### 1st: Secrets

Talos takes care of generating Tokens and Certificates for our cluster. This can be done using `just gen-secrets` in this repo.

The secrets are used for all future steps. You should **save the `secrets.yaml` file** and **keep it private**.

### 2nd: Configuration

With the secrets created, we can now create a configuration for a specific node: `just gen-config @talos/patches/rpi4-controlplane.yaml`

The `@filepath` notation is what the `talosctl` command uses. It simply points to a patch file.

This will generate some files: `worker.yaml` and `controlplane.yaml` which are the actual Node configuration. Currently, we're only interested in the `controlplane.yaml` file, since we run a single-node cluster.

We use the `talosconfig` file together with a direnv entry `export TALOSCONFIG=$(expand_path ./talosconfig)` to make `talosctl` use the local file generated in this repo.

### 3rd: Apply Configuration

To apply the generated configuration to a fresh device with the [Talos Raspberry PI Image](https://www.talos.dev/v1.7/talos-guides/install/single-board-computers/rpi_generic/#download-the-image) already flashed, simply run `just apply-config <ip>`

> [!NOTE]
> When applying config to a _freshly flashed_ node, we need the `insecure` flag, because no TLS secrets to secure the connection have been set up yet: `just apply-config <ip> insecure`
>
> When later applying config changes, the flag must be dropped, to verify the connection.

Since this guide assumes you're building a single-instance cluster, it will apply the `controlplane.yaml`. The control-plane is set up to allow scheduling workloads to it, so that it will actually run containers.

To be able to talk to the new Talos node via `talosctl` tool, we'll need to update our local `talosconfig` file to include a Node and Endpoint entry - this should point to the static IP given to the new control plane node: `just update-config <ip>`

### 4th: Download Kubeconfig

After applying the configuration, ensure everything is up and running using `talosctl health` - This should print OK for everything (might take some time while the node is fully booting).

> [!NOTE]
> By default, the etcd waits to join an existing cluster. If there are no other nodes with a running etcd, it will wait forever.
>
> We need to tell _a single instance_ to [bootstrap etcd](https://www.talos.dev/v1.7/learn-more/control-plane/#bootstrapping-the-control-plane), which for our single-instance cluster will be our one control node. Run `just bootstrap <ip>` to do so.

To be able to talk to the node via `kubectl`, run `just kubeconfig` to download the configuration to the local `./kubeconfig` file. Again, we use a direnv entry `export TALOSCONFIG=$(expand_path ./talosconfig)` to make `kubectl` use the local file in this repository.
