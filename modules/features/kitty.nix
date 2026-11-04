{
  self,
  inputs,
  withSystem,
  ...
}:
{
  perSystem = { pkgs, ... }: {
    packages.myKitty = inputs.wrapper-modules.wrappers.kitty.wrap {
      inherit pkgs;

      font = {
        name = "JetBrainsMono Nerd Font";
        size = 11;
      };

      settings = {
        background_opacity = 0.9;
        window_padding_width = 14;
        hide_window_decorations = true;

        cursor_shape = "block";
        cursor_blink_interval = 0;
        shell_integration = "no-cursor";

        enable_audio_bell = false;

        tab_bar_edge = "bottom";
        tab_bar_style = "powerline";
        tab_powerline_style = "slanted";

        # Smooth cursor
        cursor_trail = 1;
        cursor_trail_decay = "0.1 0.25";
        cursor_trail_start_threshold = 1;
      };

      extraConfig = ''
        				include ~/.config/kitty/themes/noctalia.conf
        			'';

      # Only bin/kitty gets --config by default. Launching kitty.app from
      # Spotlight, the Dock, or Finder runs the bundle's own executable, so
      # wrap that too. It must be a binary: macOS expects a Mach-O
      # CFBundleExecutable.
      wrapperVariants = pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
        "kitty.app" = {
          exePath = "Applications/kitty.app/Contents/MacOS/kitty";
          binDir = "Applications/kitty.app/Contents/MacOS";
          binName = "kitty";
          wrapperImplementation = "binary";
        };
      };
    };
  };

  flake.nixosModules.kitty = { pkgs, ... }: {
    environment.systemPackages = [
      (withSystem pkgs.stdenv.hostPlatform.system ({ self', ... }: self'.packages.myKitty))
    ];

    fonts.packages = [
      pkgs.nerd-fonts.jetbrains-mono
    ];

    environment.sessionVariables.TERMINAL = "kitty";
  };

  flake.darwinModules.kitty = { config, lib, pkgs, ... }: {
    # Hosts specialize the wrapped package here, e.g. with their own theme.
    options.programs.kitty.package = lib.mkOption {
      type = lib.types.package;
      default = withSystem pkgs.stdenv.hostPlatform.system ({ self', ... }: self'.packages.myKitty);
      description = "The configured kitty package to install.";
    };

    config = {
      environment.systemPackages = [ config.programs.kitty.package ];

      fonts.packages = [
        pkgs.nerd-fonts.jetbrains-mono
      ];

      environment.variables.TERMINAL = "kitty";

      # The bundle executable embeds the kitty.conf store path, so it changes
      # with every config edit. nix-darwin's rsync replaces it in place with
      # the same 1970 mtime, LaunchServices keeps its record of the old
      # binary, and macOS kills the new one with "Launch Constraint
      # Violation". Re-registering the bundle refreshes that record.
      system.activationScripts.postActivation.text = ''
        sudo --user=${config.system.primaryUser} -- \
          /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
          -f '/Applications/Nix Apps/kitty.app' || true
      '';
    };
  };
}
