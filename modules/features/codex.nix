{ ... }:
{
  flake.nixosModules.codex = { pkgs, lib, ... }:
    let
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
        unslop = pkgs.fetchFromGitHub {
          owner = "theclaymethod";
          repo = "unslop";
          rev = "17ed39c9d0b522f44190ff0c6233867eadee192a";
          hash = "sha256-M/w0ASIxhBmcSS2eNOh92IRb5hJg1cugLoCLbsC34Oo=";
        };
      } // mattPocockSkills;
    in
    {
      environment.systemPackages = [
        pkgs.codex
        pkgs.python3
      ];

      environment.etc = lib.mapAttrs' (
        name: source:
        lib.nameValuePair "codex/skills/${name}" {
          inherit source;
        }
      ) skills;
    };
}
