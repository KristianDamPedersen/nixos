{ self, inputs, ...} : {
	perSystem = { pkgs, ...}: {
		packages.myNoctalia = inputs.wrapper-modules.wrappers.noctalia-shell.wrap {
			inherit pkgs;

			# Add Moon alongside the bundled original Rosé Pine palette.
			package = pkgs.noctalia-shell.overrideAttrs (old: {
				postInstall = (old.postInstall or "") + ''
					mkdir -p "$out/share/noctalia-shell/Assets/ColorScheme/Rose-Pine-Moon"
					cp ${pkgs.writeText "Rose-Pine-Moon.json" (builtins.toJSON
						(builtins.fromJSON (builtins.readFile ./noctalia.json)).rosePineMoon)} \
						"$out/share/noctalia-shell/Assets/ColorScheme/Rose-Pine-Moon/Rose-Pine-Moon.json"
				'';
			});

			runtimePkgs = [
				{
					data = pkgs.kitty;
					prefix = true;
				}
			];
			settings = 
				(builtins.fromJSON
					(builtins.readFile ./noctalia.json)).settings;
		};
	};
}
