{ ... }:
{
  flake.nixosModules.openssl = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.openssl ];
  };
}
