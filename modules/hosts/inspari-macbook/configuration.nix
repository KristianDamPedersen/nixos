{ self, withSystem, ... }: {
  flake.darwinModules.inspariMacbookConfiguration = { pkgs, ... }:
    let
      self' = withSystem pkgs.stdenv.hostPlatform.system ({ self', ... }: self');
    in
    {
    imports = [
      self.darwinModules.kitty
      self.darwinModules.herdr
      self.darwinModules.codex
      self.darwinModules.claudeCode
      self.darwinModules.github
      self.darwinModules.devenv
      self.darwinModules.omniwm
      self.darwinModules.neovim
    ];

    nixpkgs.hostPlatform = "aarch64-darwin";

    # Noctalia generates the shared kitty theme on Linux only; this machine
    # uses Gruvbox instead.
    programs.kitty.package = self'.packages.myKitty.wrap {
      themeFile = "gruvbox-dark";
    };

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

    # Free the screen edges for the tiling window manager: the menu bar and
    # Dock stay hidden until the pointer reaches them.
    system.defaults.NSGlobalDomain._HIHideMenuBar = true;
    system.defaults.dock = {
      autohide = true;
      autohide-delay = 0.0;
      autohide-time-modifier = 0.15;
      show-recents = false;
    };

    system.stateVersion = 7;
  };
}
