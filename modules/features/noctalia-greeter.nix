{ ... }: {
	flake.nixosModules.noctaliaGreeter = { ... }: let
		moon = (builtins.fromJSON (builtins.readFile ./noctalia.json)).rosePineMoon.dark;
	in {
		services.displayManager.gdm.enable = false;
		environment.etc."backgrounds/clouds.jpg".source =
			../../backgrounds/clouds.jpg;

		services.displayManager.noctalia-greeter = {
			enable = true;
			settings = {
				keyboard.layout = "dk";

				session.default = "niri";
				user.default = "kristian";

				appearance = {
					scheme = "Synced";
					theme_mode = "dark";
					wallpaper = {
						path = "/etc/backgrounds/clouds.jpg";
						fill_mode = "crop";
					};
					corner_radius_scale = 0.3;
					password_style = "default";
					palette = {
						primary = moon.mPrimary;
						on_primary = moon.mOnPrimary;
						secondary = moon.mSecondary;
						on_secondary = moon.mOnSecondary;
						tertiary = moon.mTertiary;
						on_tertiary = moon.mOnTertiary;
						error = moon.mError;
						on_error = moon.mOnError;
						surface = moon.mSurface;
						on_surface = moon.mOnSurface;
						surface_variant = moon.mSurfaceVariant;
						on_surface_variant = moon.mOnSurfaceVariant;
						outline = moon.mOutline;
						shadow = moon.mShadow;
						hover = moon.mHover;
						on_hover = moon.mOnHover;
					};
					hide_logo = true;
					scheme_selector_position = "hidden";
					power_buttons_position = "bottom-right";
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
