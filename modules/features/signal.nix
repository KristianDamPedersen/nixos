{ ... }:
{
  flake.nixosModules.signal = { pkgs, ... }:
    let
      preferences = {
        theme-setting = "dark";
      };

      applyPreferences = pkgs.writeShellApplication {
        name = "signal-apply-preferences";

        text = ''
          exec ${pkgs.python3}/bin/python3 - <<'PY'
          import json
          import os
          import tempfile
          from pathlib import Path

          # Leave settings alone when Signal is already running.
          signal_app = "${pkgs.signal-desktop}/share/signal-desktop/app.asar"
          for process in Path("/proc").iterdir():
              if not process.name.isdigit():
                  continue
              try:
                  if process.stat().st_uid != os.getuid():
                      continue
                  arguments = (process / "cmdline").read_bytes().split(b"\0")
                  if os.fsencode(signal_app) in arguments:
                      raise SystemExit(0)
              except OSError:
                  continue

          config_home = Path(
            os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config"
          )
          target = config_home / "Signal" / "ephemeral.json"
          target.parent.mkdir(parents=True, exist_ok=True)
          settings = json.loads(target.read_text()) if target.exists() else {}
          settings.update(json.loads(${builtins.toJSON (builtins.toJSON preferences)}))

          fd, temporary = tempfile.mkstemp(dir=target.parent)
          try:
            with os.fdopen(fd, "w") as output:
              json.dump(settings, output, indent=2)
              output.write("\n")
            os.replace(temporary, target)
          finally:
            if os.path.exists(temporary):
              os.unlink(temporary)
          PY
        '';
      };

      configuredSignal = pkgs.symlinkJoin {
        name = "signal-desktop-configured";
        paths = [ pkgs.signal-desktop ];
        nativeBuildInputs = [ pkgs.makeWrapper ];

        postBuild = ''
          wrapProgram "$out/bin/signal-desktop" \
            --run "${applyPreferences}/bin/signal-apply-preferences"
        '';

        meta.mainProgram = "signal-desktop";
      };
    in
    {
      environment.systemPackages = [
        configuredSignal
      ];
    };
}
