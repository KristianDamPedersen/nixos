{ self, withSystem, ... }: {
  flake.nixosModules.laptopConfiguration =
    { pkgs, lib, ... }:
    let
      self' = withSystem pkgs.stdenv.hostPlatform.system ({ self', ... }: self');
    in

    {
      imports = [
        # Include the results of the hardware scan.
        self.nixosModules.laptopHardware
        self.nixosModules.niri
        self.nixosModules.breakpadWorkaround
        self.nixosModules.github
        self.nixosModules.git
        self.nixosModules.passwordManager
        self.nixosModules.librewolf
        self.nixosModules.kitty
        self.nixosModules.loginScreen
        self.nixosModules.emacs
        self.nixosModules.mail
        self.nixosModules.herdr
        self.nixosModules.repositories
        self.nixosModules.devenv
      ];

      # Niri rendering override to fix slow external display and screen flickering
      programs.niri.package = lib.mkForce (
        self'.packages.myNiri.wrap {
          settings.debug.render-drm-device = "/dev/dri/by-path/pci-0000:01:00.0-render";
        }
      );

      nix.settings.experimental-features = [
        "nix-command"
        "flakes"
      ];

      # Git config override
      programs.git.config = {
        user.name = "Kristian Pedersen";
        user.email = "kristian.dam.pedersen@gmail.com";
      };

      boot.loader = {
        efi.canTouchEfiVariables = true;

        grub = {
          enable = true;
          efiSupport = true;
          devices = lib.mkForce [ "nodev" ];
          useOSProber = false;
        };
      };

      networking.hostName = "laptop"; # Define your hostname.

      swapDevices = [
        {
          device = "/swapfile";

          # ABOUT 50% of your RAM, expressed in MiB.
          size = 8 * 1024;
        }
      ];

      networking.wireless.enable = true; # Enables wireless support via wpa_supplicant.

      # Configure network proxy if necessary
      # networking.proxy.default = "http://user:password@proxy:port/";
      # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

      # Enable networking
      networking.networkmanager.enable = true;

      # Set your time zone.
      time.timeZone = "Europe/Copenhagen";

      # Select internationalisation properties.
      i18n.defaultLocale = "en_DK.UTF-8";

      i18n.extraLocaleSettings = {
        LC_ADDRESS = "da_DK.UTF-8";
        LC_IDENTIFICATION = "da_DK.UTF-8";
        LC_MEASUREMENT = "da_DK.UTF-8";
        LC_MONETARY = "da_DK.UTF-8";
        LC_NAME = "da_DK.UTF-8";
        LC_NUMERIC = "da_DK.UTF-8";
        LC_PAPER = "da_DK.UTF-8";
        LC_TELEPHONE = "da_DK.UTF-8";
        LC_TIME = "da_DK.UTF-8";
      };

      # Configure keymap in X11
      services.xserver.xkb = {
        layout = "dk";
        variant = "";
      };

      # Configure console keymap
      console.keyMap = "dk-latin1";

      # Define a user account. Don't forget to set a password with ‘passwd’.
      users.users."kristian" = {
        isNormalUser = true;
        description = "Kristian Dam Pedersen";
        extraGroups = [
          "networkmanager"
          "wheel"
        ];
        packages = with pkgs; [
          neovim
        ];
      };

      # Enable printer discovery
      services.avahi = {
        enable = true;
        nssmdns4 = true;
        openFirewall = true;
      };

      services.printing = {
        enable = true;
        drivers = with pkgs; [
          cups-filters
          cups-browsed
        ];
      };

      # Enable the Gnome desktop
      services.desktopManager.gnome.enable = true;

      # Allow unfree packages
      nixpkgs.config.allowUnfree = true;

      system.stateVersion = "26.05";
    };
}
