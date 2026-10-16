{ ... }:
{
  flake.nixosModules.codex = { pkgs, lib, ... }:
    let
      skills = {
        unslop = pkgs.fetchFromGitHub {
          owner = "theclaymethod";
          repo = "unslop";
          rev = "17ed39c9d0b522f44190ff0c6233867eadee192a";
          hash = "sha256-M/w0ASIxhBmcSS2eNOh92IRb5hJg1cugLoCLbsC34Oo=";
        };
      };
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
