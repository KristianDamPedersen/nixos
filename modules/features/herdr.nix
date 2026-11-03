{ self, inputs, ... }:
let
  # Uses only options shared by NixOS and nix-darwin; each class imports its
  # own agent modules.
  herdrModule = agentModules: { pkgs, ... }: {
    imports = agentModules;

    environment.systemPackages = [
      inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
  };
in
{
  flake.nixosModules.herdr = herdrModule [
    self.nixosModules.codex
    self.nixosModules.claudeCode
  ];
  flake.darwinModules.herdr = herdrModule [
    self.darwinModules.codex
    self.darwinModules.claudeCode
  ];
}
