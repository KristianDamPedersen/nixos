/*
  OpenCode, wrapped with the shared agent configuration. The wrapper sets
  OPENCODE_CONFIG, which OpenCode merges over the user's global config, so
  personal and project settings still apply.
*/
{ self, inputs, ... }:
let
  # Uses only options shared by NixOS and nix-darwin; each class imports its
  # own agentConfig module.
  opencodeModule = agentConfigModule: { config, pkgs, ... }:
    let
      skills = pkgs.linkFarm "opencode-skills" config.agentSkills;
      instructions = pkgs.writeText "opencode-instructions.md" (
        config.agentInstructions skills
      );
      # Self-hosted OpenAI-compatible server on zoe.
      zoeModels = {
        "mistral-small-4" = {
          name = "Mistral Small 4 (zoe)";
          limit = {
            context = 262144;
            output = 32768;
          };
        };
      };
    in
    {
      imports = [
        agentConfigModule
      ];

      environment.systemPackages = [
        (inputs.wrapper-modules.wrappers.opencode.wrap {
          inherit pkgs;

          settings = {
            "$schema" = "https://opencode.ai/config.json";
            instructions = [ "${instructions}" ];
            skills.paths = [ "${skills}" ];
            provider = {
              # Direct cable: this machine needs an address in 10.77.0.0/24.
              zoe = {
                npm = "@ai-sdk/openai-compatible";
                name = "zoe";
                options.baseURL = "http://10.77.0.2:8000/v1";
                models = zoeModels;
              };
              # On the home network: zoe's DHCP lease on the router.
              zoe-lan = {
                npm = "@ai-sdk/openai-compatible";
                name = "zoe (LAN)";
                options.baseURL = "http://192.168.0.227:8000/v1";
                models = zoeModels;
              };
            };
          };
        })
      ];
    };
in
{
  flake.nixosModules.opencode = opencodeModule self.nixosModules.agentConfig;
  flake.darwinModules.opencode = opencodeModule self.darwinModules.agentConfig;
}
