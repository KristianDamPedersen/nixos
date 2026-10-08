{ ... }: {
	flake.nixosModules.noctaliaGreeter = { ... }: {
		services.displayManager.gdm.enable = false;

		services.displayManager.noctalia-greeter = {
			enable = true;
			settings = {
				keyboard.layout = "dk";

				session.default = "niri";
				user.default = "kristian";

				appearance = {
					hide_logo = true;
					scheme_selector_position = "hidden";
					power_buttons_position = "bottom_right";
				};

				clock = {
					enabled = true;
					time_format = "%H:%M";
					date_format = "%A, %d %B";
				};
			};
		};
	};
}
