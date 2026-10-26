{ ... }:
{
  flake.nixosModules.lutris = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.lutris ];

    # Lutris runners and games may need 32-bit graphics libraries.
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };
  };
}
