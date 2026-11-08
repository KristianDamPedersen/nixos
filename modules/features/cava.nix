{ inputs, withSystem, ... }:
let
  cava = { pkgs, ... }: {
    environment.systemPackages = [
      (withSystem pkgs.stdenv.hostPlatform.system ({ self', ... }: self'.packages.myCava))
    ];
  };
in
{
  perSystem = { pkgs, lib, ... }: {
    packages.myCava = inputs.wrapper-modules.wrappers.cava.wrap {
      inherit pkgs;

      settings = {
        general = {
          framerate = 30;
          max_height = 35;
        };

        input = lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
          method = "coreaudio";
          source = "tap";
        };

        color = {
          gradient = 1;
          gradient_count = 3;
          gradient_color_1 = "'#689d6a'";
          gradient_color_2 = "'#fabd2f'";
          gradient_color_3 = "'#fb4934'";
        };

        smoothing.noise_reduction = 90;
      };
    };
  };

  flake.nixosModules.cava = cava;
  flake.darwinModules.cava = cava;
}
