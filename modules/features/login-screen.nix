{inputs, ... }: {
	flake.nixosModules.loginScreen = { ... }: {
		imports = [ inputs.silentSDDM.nixosModules.default ];

		services.displayManager.gdm.enable = false;
		services.displayManager.noctalia-greeter.enable = false;
		services.displayManager.defaultSession = "niri";

		environment.etc."backgrounds/clouds.jpg".source =
			../../backgrounds/clouds.jpg;

		programs.silentSDDM = {
			enable = true;
			theme = "default";

			backgrounds.clouds = ../../backgrounds/clouds.jpg;

			settings = {
				"General" = {
					scale = 1.0;
					enable-animations = true;
				};

				"LockScreen" = {
					display = true;
					background = "clouds.jpg";
					blur = 0;
					brightness = 0.0;
				};

				"LoginScreen" = {
					background = "clouds.jpg";
					blur = 24;
					brightness = 0.0;
					saturation = 0.0;
				};

				"LoginScreen.LoginArea".position = "center";

				"LoginScreen.LoginArea.Avatar" = {
					active-size = 64;
					inactive-size = 48;
					active-border-size = 0;
					inactive-border-size = 0;
				};

				"LoginScreen.LoginArea.Username" = {
					font-size = 14;
					font-weight = 500;
					color = "#e0def4";
					margin = 8;
				};

				"LoginScreen.LoginArea.PasswordInput" = {
					width = 220;
					height = 32;
					display-icon = false;
					content-color = "#e0def4";
					background-color = "#2a273f";
					background-opacity = 1.0;
					border-size = 0;
					border-radius-left = 5;
					border-radius-right = 5;
					margin-top = 8;
				};

				"LoginScreen.LoginArea.LoginButton" = {
					background-color = "#2a273f";
					background-opacity = 1.0;
					active-background-color = "#ea9a97";
					active-background-opacity = 1.0;
					content-color = "#e0def4";
					active-content-color = "#232136";
					border-radius-left = 5;
					border-radius-right = 5;
					margin-left = 4;
				};

				"LoginScreen.MenuArea.Buttons" = {
					margin-top = 24;
					margin-right = 24;
					margin-bottom = 24;
					margin-left = 24;
					size = 28;
					spacing = 8;
					border-radius = 5;
				};

				"LoginScreen.MenuArea.Popups" = {
					background-color = "#232136";
					background-opacity = 1.0;
					content-color = "#e0def4";
					active-option-background-color = "#44415a";
					active-option-background-opacity = 1.0;
					active-content-color = "#e0def4";
				};

				"LoginScreen.MenuArea.Session" = {
					display = true;
					position = "bottom-left";
					display-session-name = true;
					button-width = 160;
					popup-width = 220;
					font-size = 12;
					content-color = "#e0def4";
				};

				"LoginScreen.MenuArea.Power" = {
					position = "bottom-right";
					content-color = "#e0def4";
				};

				"LoginScreen.MenuArea.Keyboard".display = false;

				"Tooltips" = {
					background-color = "#232136";
					background-opacity = 1.0;
					content-color = "#e0def4";
				};
			};
		};
	};
}
