# flake-parts declares `flake.nixosModules` but no longer ships a
# `darwinModules` option. Declare it the same way so several files can
# contribute to one named nix-darwin module through ordinary merging.
{ lib, moduleLocation, ... }:
{
  options.flake.darwinModules = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.deferredModule;
    default = { };
    apply = lib.mapAttrs (
      name: module: {
        _class = "darwin";
        _file = "${toString moduleLocation}#darwinModules.${name}";
        imports = [ module ];
      }
    );
    description = "nix-darwin modules.";
  };
}
