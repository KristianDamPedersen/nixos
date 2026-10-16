{ self, inputs, ... }:
{
  flake.nixosModules.herdr = { pkgs, ... }: {
    imports = [
      self.nixosModules.codex
    ];

    environment.systemPackages = [
      inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
  };
}
