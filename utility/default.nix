# todo how to build this via CI?
# build with `nix-build default.nix`
# No need to specify nixpkgs, it's conditionally imported (can be overridden)
# Mostly from https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/docker/examples.nix
# https://github.com/moby/moby/blob/master/image/spec/v1.2.md#image-json-field-descriptions
# https://nixos.org/manual/nixpkgs/stable/#sec-pkgs-dockerTools
# https://nix.dev/tutorials/continuous-integration-github-actions#caching-builds-using-cachix

{ pkgs ? import <nixpkgs> {},
  # This probably won't work in GitHub Actions?
  pkgsLinux ? import <nixpkgs> { system = "aarm64-linux"; }
}:

let
  justfile = pkgs.writeText "justfile" ''
  version:
    just --version
    restic version
    curl --version
  
  restic-safe-init:
    #!/bin/bash
    restic snapshots
    if [ $? -ne 0 ]; then restic init; fi
  
  restic-backup:
    restic backup . --no-cache --host {{env_var('BACKUP_NAME')}}
  
  restic-retain:
    restic forget --host {{env_var('BACKUP_NAME')}} --keep-daily {{env_var('BACKUP_KEEP_DAILY')}} --keep-weekly {{env_var('BACKUP_KEEP_WEEKLY')}} --keep-monthly {{env_var('BACKUP_KEEP_MONTHLY')}}
  
  restic-prune:
    # actually remove the data - LOCKS the repo, can't make new backups!
    restic prune
    # verify integrity of reopsitory
    restic check
    # todo run this on a different schedule!
  
  backup: restic-safe-init restic-backup restic-retain

  healthcheck-io:
    https --timeout 10 {{env_var('HEALTHCHECK_IO_URL')}}
  '';
in pkgs.dockerTools.buildImage {
  name = "backup-util";
  tag = "latest";
  copyToRoot = pkgs.buildEnv {
    name = "image-root";
    pathsToLink = [ "/bin" ];
    paths = with pkgs; [ tini bash restic just httpie ];
  };
  config = {
    WorkingDir = "/workdir";
    Entrypoint = [ "${pkgs.tini}/bin/tini" "--" "${pkgs.just}/bin/just" "-f" justfile ];
    Cmd = [ "-l" ];
  };
}