{ self, ... }: {
  flake.darwinModules.inspariMacbookConfiguration = { ... }: {
    imports = [
      self.darwinModules.kitty
      self.darwinModules.herdr
      self.darwinModules.codex
      self.darwinModules.claudeCode
      self.darwinModules.github
    ];

    nixpkgs.hostPlatform = "aarch64-darwin";

    # Allow unfree packages (claude-code)
    nixpkgs.config.allowUnfree = true;

    # nix-darwin manages the Nix installation and daemon on this host.
    nix.enable = true;
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];

    networking = {
      hostName = "inspari-macbook";
      computerName = "inspari-macbook";
      localHostName = "inspari-macbook";
    };

    # The macOS account on this machine is `krdp`, not `kristian`.
    system.primaryUser = "krdp";
    users.users.krdp.home = "/Users/krdp";

    # The checkout lives in ~/.dotfiles/nixos; expose it at the path the
    # other hosts use so `--flake /etc/nixos#inspari-macbook` works.
    environment.etc."nixos".source = "/Users/krdp/.dotfiles/nixos";

    time.timeZone = "Europe/Copenhagen";

    system.stateVersion = 7;
  };
}
