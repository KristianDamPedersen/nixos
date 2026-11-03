/*
  Claude Code, with the shared agent configuration installed as managed
  (system-wide) configuration. Claude Code loads managed skills from
  `.claude/skills/` and managed instructions from `CLAUDE.md` inside its
  managed settings directory:
    * Linux: /etc/claude-code
    * macOS: /Library/Application Support/ClaudeCode

  claude-code is unfree; hosts importing this feature must allow unfree packages.
*/
{ self, ... }:
{
  flake.nixosModules.claudeCode = { config, pkgs, lib, ... }: {
    # Hosts and herdr may both import this; load it once.
    key = "claudeCode";

    imports = [
      self.nixosModules.agentConfig
    ];

    environment.systemPackages = [
      pkgs.claude-code
    ];

    environment.etc = {
      "claude-code/CLAUDE.md".text = config.agentInstructions "/etc/claude-code/.claude/skills";
    } // lib.mapAttrs' (
      name: source:
      lib.nameValuePair "claude-code/.claude/skills/${name}" {
        inherit source;
      }
    ) config.agentSkills;
  };

  flake.darwinModules.claudeCode = { config, pkgs, lib, ... }:
    let
      managedDir = "/Library/Application Support/ClaudeCode";
      managedSkillsDir = lib.escapeShellArg "${managedDir}/.claude/skills";
      managedInstructions = lib.escapeShellArg "${managedDir}/CLAUDE.md";
      skills = pkgs.linkFarm "claude-code-skills" config.agentSkills;
      instructions = pkgs.writeText "claude-code-CLAUDE.md" (
        config.agentInstructions "${managedDir}/.claude/skills"
      );
    in
    {
      # Hosts and herdr may both import this; load it once.
      key = "claudeCode";

      imports = [
        self.darwinModules.agentConfig
      ];

      environment.systemPackages = [
        pkgs.claude-code
      ];

      # nix-darwin's environment.etc only writes under /etc, so link the
      # instructions and each skill during activation. Links into the Nix store
      # are owned by this script and replaced on every activation; other files
      # are left alone.
      system.activationScripts.postActivation.text = ''
        echo "setting up Claude Code managed configuration..." >&2
        mkdir -p ${managedSkillsDir}
        find ${managedSkillsDir} -mindepth 1 -maxdepth 1 -type l -lname '/nix/store/*' -delete
        for skill in ${skills}/*; do
          ln -sfn "$(readlink "$skill")" ${managedSkillsDir}/"$(basename "$skill")"
        done
        if [ -e ${managedInstructions} ] && [ ! -L ${managedInstructions} ]; then
          echo "warning: not replacing unmanaged "${managedInstructions} >&2
        else
          ln -sfn ${instructions} ${managedInstructions}
        fi
      '';
    };
}
