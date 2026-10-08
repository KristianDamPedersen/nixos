{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";

    wrapper-modules.url = "github:BirdeeHub/nix-wrapper-modules";

    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    doom = {
        url = "github:marienz/nix-doom-emacs-unstraightened/6d5cdc527d691c7dd0cd8266cc41ae7519fdf4e7";

        inputs.nixpkgs.follows = "nixpkgs";

        inputs.doomemacs.url = "github:doomemacs/core/59cdaa32ae933469bb6a1fb3cadee8a988c15968";

        inputs.doomemacs-modules.url = "github:doomemacs/modules/897f815447112bc6e12e0aaf63aa5435b810344b";
    };
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake {inherit inputs;} (inputs.import-tree ./modules);
}
