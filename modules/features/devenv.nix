{ inputs, ... }:
{
  flake.nixosModules.devenv = { pkgs, ... }: {
    environment.systemPackages = [
      inputs.devenv.packages.${pkgs.stdenv.hostPlatform.system}.devenv
    ];
  };
}
