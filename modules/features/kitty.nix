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

  flake.darwinModules.kitty = { pkgs, ... }:
    let
      myKitty = withSystem pkgs.stdenv.hostPlatform.system ({ self', ... }: self'.packages.myKitty);
    in
    {
      environment.systemPackages = [ myKitty ];

      fonts.packages = [
        pkgs.nerd-fonts.jetbrains-mono
      ];

      environment.variables.TERMINAL = "kitty";

      # Only bin/kitty passes --config. Launching kitty.app from Finder or
      # Spotlight runs the unwrapped binary, which reads its configuration
      # from KITTY_CONFIG_DIRECTORY. The wrapped package keeps kitty.conf at
      # its root.
      launchd.user.envVariables.KITTY_CONFIG_DIRECTORY = "${myKitty}";
    };
}
