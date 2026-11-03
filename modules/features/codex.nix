{ self, ... }:
let
  # Uses only options shared by NixOS and nix-darwin; each class imports its
  # own agentConfig module.
  codexModule = agentConfigModule: { config, pkgs, lib, ... }:
    {
      # Hosts and herdr may both import this; load it once.
      key = "codex";

      imports = [
        agentConfigModule
      ];

      environment.systemPackages = [
        pkgs.codex
        pkgs.python3
      ];

      # System defaults also apply outside repositories and through Codex clients.
      environment.etc = {
        "codex/config.toml".source =
          (pkgs.formats.toml { }).generate "codex-config.toml" {
            developer_instructions = config.agentInstructions "/etc/codex/skills";
          };

      } // lib.mapAttrs' (
        name: source:
        lib.nameValuePair "codex/skills/${name}" {
          inherit source;
        }
      ) config.agentSkills;
    };
in
{
  flake.nixosModules.codex = codexModule self.nixosModules.agentConfig;
  flake.darwinModules.codex = codexModule self.darwinModules.agentConfig;
}
