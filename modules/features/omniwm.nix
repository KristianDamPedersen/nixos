/*
  OmniWM: Niri-style scrolling tiling window manager for macOS.

  Importing the Darwin module installs OmniWM and starts it at login from a
  launchd user agent. Quitting from the menu bar icon keeps it stopped until
  the next login. See docs/research/macos-tiling-window-managers.md.

  OmniWM reads ~/.config/omniwm/settings.toml and the settings window writes
  back to it. The agent links that path to config/omniwm/settings.toml in the
  checkout, so settings-window changes show up as Git diffs. OmniWM rewrites
  the link's target and strips comments, so explanations belong here.

  Accessibility and Input Monitoring must be granted by hand on first launch.
*/
{ ... }:
let
  # Pinned nixpkgs ships 0.7.1. The keymap research targets the 0.7.6
  # action IDs. Drop this override once nixpkgs catches up.
  omniwmFor =
    pkgs:
    pkgs.omniwm.overrideAttrs (
      finalAttrs: _: {
        version = "0.7.6";
        src = pkgs.fetchurl {
          url = "https://github.com/OmniNull/OmniWM/releases/download/v${finalAttrs.version}/OmniWM-v${finalAttrs.version}.zip";
          hash = "sha256-7IxhRqbyGnnhxArHDWESF2K5PPU80wjmPrROis4g/Nw=";
        };
      }
    );

  # A mutable path into the checkout, not a store path, because OmniWM writes
  # to it. /etc/nixos points at the checkout on every host. OmniWM validates
  # settings.toml strictly and rejects partial files, so the repo copy must
  # stay a complete file exported by OmniWM.
  checkoutSettings = "/etc/nixos/config/omniwm/settings.toml";
in
{
  flake.darwinModules.omniwm =
    { pkgs, ... }:
    let
      omniwm = omniwmFor pkgs;

      launcher = pkgs.writeShellApplication {
        name = "omniwm-launcher";
        text = ''
          settings="$HOME/.config/omniwm/settings.toml"
          if [ "$(readlink "$settings")" != ${checkoutSettings} ]; then
            mkdir -p "$(dirname "$settings")"
            # Keep a file written before the link existed.
            if [ -e "$settings" ] && [ ! -L "$settings" ]; then
              mv "$settings" "$settings.pre-link"
            fi
            ln -sfn ${checkoutSettings} "$settings"
          fi
          exec ${omniwm}/Applications/OmniWM.app/Contents/MacOS/OmniWM
        '';
      };
    in
    {
      key = "omniwm";

      # Also puts OmniWM.app in /Applications/Nix Apps and omniwmctl on PATH.
      environment.systemPackages = [ omniwm ];

      # OmniWM pauses window management unless each display has its own
      # Spaces. This is the macOS default; it takes effect after logout.
      system.defaults.spaces.spans-displays = false;

      launchd.user.agents.omniwm.serviceConfig = {
        ProgramArguments = [ (pkgs.lib.getExe launcher) ];
        RunAtLoad = true;
        # Restart after a crash, but respect a quit from the menu bar.
        KeepAlive.SuccessfulExit = false;
        ProcessType = "Interactive";
      };
    };
}
