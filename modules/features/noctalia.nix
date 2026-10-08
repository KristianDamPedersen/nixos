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
					substituteInPlace \
						"$out/share/noctalia-shell/Services/UI/WallpaperService.qml" \
						--replace-fail \
						'Quickshell.shellDir + "/Assets/Wallpaper/noctalia.png"' \
						'"${../../backgrounds/clouds.jpg}"'

					# Keep the lock-screen password panel compact on every display.
					substituteInPlace \
						"$out/share/noctalia-shell/Modules/LockScreen/LockScreenPanel.qml" \
						--replace-fail \
						'width: Settings.data.general.showHibernateOnLockScreen ? 860 : 810' \
						'width: Math.min(420, parent.width - 48)'

					# Use the user's name and quieter typography in the header.
					substituteInPlace \
						"$out/share/noctalia-shell/Modules/LockScreen/LockScreenHeader.qml" \
						--replace-fail \
						'text: I18n.tr("system.welcome-back") + " " + HostService.displayName + "!"' \
						'text: HostService.displayName' \
						--replace-fail \
						'pointSize: Style.fontSizeXL' \
						'pointSize: Style.fontSizeM' \
						--replace-fail \
						'pointSize: Style.fontSizeXXL' \
						'pointSize: Style.fontSizeXL'
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
