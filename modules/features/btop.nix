{ inputs, withSystem, ... }:
let
  btop = { pkgs, ... }: {
    environment.systemPackages = [
      (withSystem pkgs.stdenv.hostPlatform.system ({ self', ... }: self'.packages.myBtop))
    ];
  };
in
{
  perSystem = { pkgs, ... }: {
    packages.myBtop = inputs.wrapper-modules.wrappers.btop.wrap {
      inherit pkgs;

      settings.color_theme = "gruvbox";
      themes.gruvbox = "${pkgs.btop}/share/btop/themes/gruvbox_dark.theme";
    };
  };

  flake.nixosModules.btop = btop;
  flake.darwinModules.btop = btop;
}
