{ inputs, ... }:
{
  flake.nixosModules.devenv = { pkgs, ... }: {
    environment.systemPackages = [
      inputs.devenv.packages.${pkgs.stdenv.hostPlatform.system}.devenv
    ];

    nix.settings = {
      extra-substituters = [
        "https://devenv.cachix.org"
      ];

      extra-trusted-public-keys = [
        "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
      ];

    };
  };
}
