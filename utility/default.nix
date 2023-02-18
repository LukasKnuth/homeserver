# Build the docker contianer for the local system arch.

let pkgs = import <nixpkgs> {};
  container = import ./container.nix;
in pkgs.callPackage (container "latest") {}
