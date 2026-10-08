{ ... }: {
	/**
		Installs the Librewolf browser.

		Features:
		* Enables dark mode
		* 1Password extension

		NOTE: The browser installs extensions on launch, so their versions are not pinned by flake.lock.
	*/
	flake.nixosModules.librewolf = { pkgs, ... }: {
		environment.systemPackages = [ 
			(pkgs.librewolf.override {
				extraPrefs = ''
					// Browser interface
					pref("extensions.activeThemeId", "firefox-compact.dark@mozilla.org");
					pref("ui.systemUsesDarkTheme", 1);

					// Websites that support a dark color scheme.
					pref("layout.css.prefers-color-scheme.content-override", 0);
				'';

				extraPolicies = {
					ExtensionSettings = {
						"{d634138d-c276-4fc8-924b-40a0ea21d284}" = {
							installation_mode = "normal_installed";
							install_url = "https://addons.mozilla.org/firefox/downloads/latest/1password-x-password-manager/latest.xpi";
						};
					};
				};
			})
		];
	};
}
