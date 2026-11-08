{ ... }:
let
  snowmachine = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.snowmachine ];
  };
in
{
  flake.nixosModules.snowmachine = snowmachine;
  flake.darwinModules.snowmachine = snowmachine;
}
