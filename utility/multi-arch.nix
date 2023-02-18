# This builds the container via cross compilition for multiple architectures.
# It's currently not used, since cross-compilition always causes binary cache
# misses, so some packages don't compile and it takes forever.
# Additionally, this will result in multiple Image files, which must be combined
# together to a multi-arch image manually:
#
#  docker manifest create --amend ${name}:${tag} ${imageName}
#
# Mostly stolen from https://gist.github.com/piperswe/6be06f58ba3925801b0dcceab22c997b
# https://nix.dev/tutorials/continuous-integration-github-actions#caching-builds-using-cachix

let nixpkgs = import <nixpkgs>;
  crossSystems = map (arch: {
    inherit arch; # add fn arg as new key "arch" in this set
    pkgs = (nixpkgs {
      crossSystem = { config = "${arch}-linux"; };
    }).pkgsStatic; # build/get static build binaries
  }) [ "x86_64" "aarch64" ];
  container = import ./container.nix;

in map({arch, pkgs}:
  pkgs.callPackage (container "latest-${arch}") {}
) crossSystems