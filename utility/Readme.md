# Utility Container

This is Nix Container setup to create a utility container to run different tasks on the cluster. It packages a minimal working linux system and a few specific tools.

## Nix Files

The configuration is split into multiple files, where both `default.nix` and `multi-arch.nix` could be called _entrypoints_.

### `container.nix`

This file contains the actual configuration to create the container. This includes the system, the image metadata, which utility to package and the Justfile. Some specifics here are notable:

**Justfile** is the configuration file for the [just](https://github.com/casey/just) command runner. It's used as the `ENTRYPOINT` for the container. This allows us to define many different receipts (just name for commands) with dependencies between them.

The file is generated for the image and is set as the default file for every invocation. This then allows specify the `ARGS` to the container, which can just be all receipts to be invoked in order and their arguments. An example in Kubernetes:

```yaml
# in a container spec
container:
- image: backup-util
  args:
  - backup
  - "test"
  - healthcheck-io
```

This will invoke the `backup` receipt with the `"test"` argument and then, _only_ if the `backup` receipt succeeded, runs the `healthcheck-io` receipt.

Just is nice, but isn't a valid init, so we need **tini** to wrap the invocation. This is required because in containers, the `ENTRYPOINT` is PID1, which is [expected to do additional work](https://saschawolf.me/2021/06/how-docker-forced-me-to-learn-more-about-linux). Mainly:

1. Reap Zombie processes (especially this, since just will spawn a lot of processes)
2. Default signal handling for any processes started by it
3. Handle shutdown by trapping signals and waiting for children to die via `SIGTERM`

All the above is handled by [tini](https://github.com/krallin/tini) and its just simply invoked in the Entrypoint.

**httpie** is used over classic curl, since I couldn't get TLS support to work for curl and [httpie](https://httpie.io/) worked out of the box.

### `default.nix`

Simply builds the container for the architecture of the current system. On my M1 MacBook, this is `aarm64`, which is also what the RaspberryPI is running, so this works out great.

As a bonus, when invoking `nix-build` without an argument, the `default.nix` file is chosen.

### `multi-arch.nix`

This was my attempt to build a multi-arch Docker image for both `x86_64` and `aarm64` in a single image as is possible with Dockers `buildx` command.

This works to _some_ extend. The main problem is that since both images are cross-compiled, every package is built from source because we will always miss cache. This makes this take forever and some packages don't cross-compile, even if they _do_ compile directly for the targeted architecture.

Maybe the better choice here is to put this work onto Docker and emulate an `x86_64` container via Rosetta 2 on OS X. Currently, this is not needed, so it remains here for prosperity.