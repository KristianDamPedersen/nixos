{ ... }: {
  flake.nixosModules.laptopHardware = { lib, ... }: {
                                    imports = [ ../../../config/hardware/laptop-hardware.nix ];
                                    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  };

}
