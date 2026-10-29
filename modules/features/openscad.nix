{ ... }:
{
  flake.nixosModules.openscad = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.openscad ];
  };
}
