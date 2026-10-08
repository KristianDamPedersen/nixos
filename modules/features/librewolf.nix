{ ... }: {
	/**
		Installs the Librewolf browser.
	*/
	flake.nixosModules.librewolf = { pkgs, ... }: {
		environment.systemPackages = [ pkgs.librewolf ];
	};
};
