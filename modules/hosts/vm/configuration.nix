{ self, inputs, withSystem, ... }: {
	flake.nixosModules.vmConfiguration = { pkgs, lib, ... }:
let
	self' = withSystem pkgs.stdenv.hostPlatform.system ({ self', ... }: self');
in
{
		imports =
			[ # Include the results of the hardware scan.
				self.nixosModules.vmHardware
				self.nixosModules.niri
				self.nixosModules.breakpadWorkaround
				self.nixosModules.github
				self.nixosModules.git
				self.nixosModules.passwordManager
			];
		
		nix.settings.experimental-features = [ "nix-command" "flakes" ];

		# Niri resolution override
		programs.niri.package = lib.mkForce (
			self'.packages.myNiri.wrap {
				settings.outputs."Virtual-1".mode = "1920x1080@60.000";
			}
		);

		# Git config override
		programs.git.config = {
			user.name = "Kristian Pedersen";
			user.email = "kristian.dam.pedersen@gmail.com";
		};

		# Use the GRUB 2 boot loader.
		boot.loader.grub.enable = true;
		boot.loader.grub.useOSProber = true;

		networking.hostName = "nixos"; # Define your hostname.
		# networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

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
		extraGroups = [ "networkmanager" "wheel" ];
		packages = with pkgs; 
			[
				neovim
				firefox
				codex
			];
		};

		# Enable the Gnome desktop
		services.displayManager.gdm.enable = true;
		services.desktopManager.gnome.enable = true;

		# Allow unfree packages
		nixpkgs.config.allowUnfree = true;

		# List packages installed in system profile.
		# You can use https://search.nixos.org/ to find more packages (and options).
		# environment.systemPackages = with pkgs; [
		#   vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
		#   wget
		# ];

		# Some programs need SUID wrappers, can be configured further or are
		# started in user sessions.
		# programs.mtr.enable = true;
		# programs.gnupg.agent = {
		#   enable = true;
		#   enableSSHSupport = true;
		# };

		# List services that you want to enable:

		# Enable the OpenSSH daemon.
		# services.openssh.enable = true;

		# Open ports in the firewall.
		# networking.firewall.allowedTCPPorts = [ ... ];
		# networking.firewall.allowedUDPPorts = [ ... ];
		# Or disable the firewall altogether.
		# networking.firewall.enable = false;

		# Copy the NixOS configuration file and link it from the resulting system
		# (/run/current-system/configuration.nix). This is useful in case you
		# accidentally delete configuration.nix.
		# system.copySystemConfiguration = true;

		# This option defines the first version of NixOS you have installed on this particular machine,
		# and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
		#
		# Most users should NEVER change this value after the initial install, for any reason,
		# even if you've upgraded your system to a new NixOS release.
		#
		# This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
		# so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
		# to actually do that.
		#
		# This value being lower than the current NixOS release does NOT mean your system is
		# out of date, out of support, or vulnerable.
		#
		# Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
		# and migrated your data accordingly.
		#
		# For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
		system.stateVersion = "26.05"; # Did you read the comment?
	};
}
