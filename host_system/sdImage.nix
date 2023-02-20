{ ... }:
{
  imports = [
    <nixpkgs/nixos/modules/installer/sd-card/sd-image-aarch64.nix>
    # For nixpkgs cache on install target
    <nixpkgs/nixos/modules/installer/cd-dvd/channel.nix>
    # The runtime configuration
    ./configuration.nix
  ];
  
  # Fix current issue https://github.com/NixOS/nixpkgs/issues/126755
  nixpkgs.overlays = [
    (final: super: {
      makeModulesClosure = x:
        super.makeModulesClosure (x // { allowMissing = true; });
    })
  ];

  # Don't compress, we flash it anyways
  sdImage.compressImage = false;
}