{ ... }:
{
  flake.nixosModules.repositories = { pkgs, ... }:
    {
      # Repository entries can be contributed by shared features or hosts.
      environment.etc."myrepos.mrconfig".text = ''
        [$HOME/src/pumpernickel]
        checkout = git clone https://github.com/KristianDamPedersen/pumpernickel.git pumpernickel
      '';

      environment.systemPackages = [
        (pkgs.writeShellApplication {
          name = "repos";

          runtimeInputs = [
            pkgs.mr
            pkgs.git
          ];

          text = ''
            exec mr \
            --config /etc/myrepos.mrconfig \
            --trust-all \
            --director "$HOME" \
            "$@"
          '';
        })
      ];
    };

}
