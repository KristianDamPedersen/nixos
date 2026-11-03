{ self, inputs, ... }: {
  flake.darwinConfigurations.inspari-macbook = inputs.nix-darwin.lib.darwinSystem {
    modules = [
      self.darwinModules.inspariMacbookConfiguration
    ];
  };
}
