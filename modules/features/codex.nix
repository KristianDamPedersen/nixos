{ ... }:
{
  flake.nixosModules.codex = { pkgs, lib, ... }:
    let
      ponytailSource = pkgs.fetchFromGitHub {
        owner = "DietrichGebert";
        repo = "ponytail";
        rev = "96608e078b2d5ea607c5c3b8b5a54d1c1fba6846";
        hash = "sha256-PhPtZbeX2wBp19GtWRy+fV93+fFYZe5S487eXPDl/us=";
      };

      ponytailSkills = lib.genAttrs [
        "ponytail"
        "ponytail-audit"
        "ponytail-debt"
        "ponytail-gain"
        "ponytail-help"
        "ponytail-review"
      ] (name: "${ponytailSource}/skills/${name}");

      cursorPluginsSource = pkgs.fetchFromGitHub {
        owner = "cursor";
        repo = "plugins";
        rev = "4dd1d05818d19792e7cd6e818f1667f95f7e1dbe";
        hash = "sha256-QW55Vg593fNhoQ2dUlr/HLV/5OkGORLZfencXEInbWk=";
      };

      mattPocockSource = pkgs.fetchFromGitHub {
        owner = "mattpocock";
        repo = "skills";
        rev = "49dd158d1076134a641b33efb035946536778336";
        hash = "sha256-NljCSZNI3sZ+vbCw7pRdrwR7try4BxOFp4gdjuWYtzs=";
      };

      mattPocockSkills = lib.genAttrs [
        "ask-matt"
        "code-review"
        "codebase-design"
        "diagnosing-bugs"
        "domain-modeling"
        "grill-with-docs"
        "implement"
        "implement-spec"
        "improve-codebase-architecture"
        "pr"
        "prototype"
        "research"
        "retro"
        "setup-matt-pocock-skills"
        "tdd"
        "to-spec"
        "to-tickets"
        "triage"
        "wayfinder"
        "wizard"
      ] (name: "${mattPocockSource}/skills/engineering/${name}")
      // lib.genAttrs [
        "grill-me"
        "grilling"
        "handoff"
        "teach"
        "to-questionaire"
        "wait-what"
        "writing-for-agents"
      ] (name: "${mattPocockSource}/skills/productivity/${name}");
      skills = {
        thermo-nuclear-code-quality-review =
          "${cursorPluginsSource}/cursor-team-kit/skills/thermo-nuclear-code-quality-review";
        unslop = pkgs.fetchFromGitHub {
          owner = "theclaymethod";
          repo = "unslop";
          rev = "17ed39c9d0b522f44190ff0c6233867eadee192a";
          hash = "sha256-M/w0ASIxhBmcSS2eNOh92IRb5hJg1cugLoCLbsC34Oo=";
        };
      } // mattPocockSkills // ponytailSkills;
    in
    {
      environment.systemPackages = [
        pkgs.codex
        pkgs.python3
      ];

      # System defaults also apply outside repositories and through Codex clients.
      environment.etc = {
        "codex/config.toml".source =
          (pkgs.formats.toml { }).generate "codex-config.toml" {
            developer_instructions = ''
              Apply the unslop skill to ALL prose you write, without waiting for
              the user to invoke it. This includes every chat reply, progress
              update, explanation, question, and prose written to files or tools.
              Read /etc/codex/skills/unslop/SKILL.md and its required references
              before writing prose; reuse those instructions throughout the session.
              Treat your own drafts as rewrite input and complete the skill's
              diagnosis, rewrite, and validation before sending or saving them.
              This is standing authorization to revise your own drafts. Follow the
              user's requested scope when auditing or editing supplied text.
              Use the crisp preset by default. Keep responses concise and direct,
              with only the detail needed to answer the question or complete the
              task. Return the finished prose; show the audit only when requested.
              Preserve facts, uncertainty, quotations, citations, and code.
            '';
          };

      } // lib.mapAttrs' (
        name: source:
        lib.nameValuePair "codex/skills/${name}" {
          inherit source;
        }
      ) skills;
    };
}
