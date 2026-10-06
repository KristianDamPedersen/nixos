{ self, inputs, ... }: {
	flake.nixosModules.niri = { pkgs, lib, ... }: {
		programs.niri = {
			enable = true;
			package = self.packages.${pkgs.stdenv.hostPlatform.system}.myNiri;
		};
	};
	perSystem = { pkgs, lib, self', ... }: {
		packages.first-window-width = pkgs.writeShellApplication {
			name = "first-window-width";
			runtimeInputs = [ pkgs.python3 pkgs.niri ];
			text = ''
				exec python3 ${./first-window-width.py}
			'';
		};
		packages.myNiri = inputs.wrapper-modules.wrappers.niri.wrap {
			inherit pkgs;
			settings = let
				keys = [ "1" "2" "3" "4" "5" "6" "7" "8" "9" "0" ];
				workspace = key: "ws-${if key == "0" then "10" else "0${key}"}";

				# Translated keybinds for danish layout
				resize = modifiers: step: {
					"Mod${modifiers}+plus".set-column-width = "-${step}";
					"Mod${modifiers}+dead_acute".set-column-width = "+${step}";
					"Mod${modifiers}+Shift+plus".set-window-height = "-${step}";
					"Mod${modifiers}+Shift+dead_acute".set-window-height = "+${step}";
				};
			in
			{
				workspaces = lib.genAttrs (map workspace keys) (_: {});
				spawn-at-startup = [
					(lib.getExe self'.packages.myNoctalia)
					(lib.getExe self'.packages.first-window-width)
				];
				input.keyboard = {
					xkb.layout = "dk";
				};
				layout.gaps = 5;
				binds = {
					# Spawn launcher
					"Mod+Space".spawn-sh =
						"${lib.getExe self'.packages.myNoctalia} ipc call launcher toggle";
					
					# Spawn terminal
					"Mod+Return".spawn-sh = lib.getExe pkgs.kitty;

					# Close, float and fullscreen
					"Mod+W".close-window = _: {};
					"Mod+Q".close-window = _: {};
					"Mod+T".toggle-window-floating = _: {};
					"Mod+F".fullscreen-window = _: {};
					"Mod+Alt+F".maximize-column = _: {};
					"Mod+Ctrl+F".toggle-windowed-fullscreen = _: {};

					# Focus in a direction.
					"Mod+Left".focus-column-left = _: {};
					"Mod+Right".focus-column-right = _: {};
					"Mod+Up".focus-window-up = _: {};
					"Mod+Down".focus-window-down = _: {};

					# Swap horizontally; reorder vertically within a column.
					"Mod+Shift+Left".swap-window-left = _: {};
					"Mod+Shift+Right".swap-window-right = _: {};
					"Mod+Shift+Up".move-window-up = _: {};
					"Mod+Shift+Down".move-window-down = _: {};

					# Workspace navigation.
					"Mod+Tab".focus-workspace-down = _: {};
					"Mod+Shift+Tab".focus-workspace-up = _: {};
					"Mod+Ctrl+Tab".focus-workspace-previous = _: {};
					"Mod+WheelScrollDown".focus-workspace-down = _: {};
					"Mod+WheelScrollUp".focus-workspace-up = _: {};

					# Monitor navigation and moving whole workspaces.
					"Ctrl+Alt+Tab".focus-monitor-next = _: {};
					"Ctrl+Alt+Shift+Tab".focus-monitor-previous = _: {};
					"Mod+Shift+Alt+Left".move-workspace-to-monitor-left = _: {};
					"Mod+Shift+Alt+Right".move-workspace-to-monitor-right = _: {};
					"Mod+Shift+Alt+Up".move-workspace-to-monitor-up = _: {};
					"Mod+Shift+Alt+Down".move-workspace-to-monitor-down = _: {};

					# Approximate Omarchy groups using Niri's tabbed columns.
					"Mod+G".toggle-column-tabbed-display = _: {};
					"Mod+Alt+Left".consume-or-expel-window-left = _: {};
					"Mod+Alt+Right".consume-or-expel-window-right = _: {};
					"Mod+Alt+Tab".focus-window-down-or-top = _: {};
					"Mod+Alt+Shift+Tab".focus-window-up-or-bottom = _: {};
					"Mod+Ctrl+Left".focus-window-up-or-bottom = _: {};
					"Mod+Ctrl+Right".focus-window-down-or-top = _: {};
  				}
				// lib.mergeAttrsList (map (key: {
					# Super + 1–0: switch workspace.
					"Mod+${key}".focus-workspace = workspace key;

					# Super + Shift + 1–0: move window and follow it.
					"Mod+Shift+${key}".move-window-to-workspace =
						[ (workspace key) { focus = true; } ];

					# Add Alt: move window without following.
					"Mod+Shift+Alt+${key}".move-window-to-workspace =
						[ (workspace key) { focus = false; } ];
				}) keys)
				
				// lib.mergeAttrsList (map (key: {
					"Mod+Alt+${key}".focus-window-in-column = lib.toInt key;
				}) [ "1" "2" "3" "4" "5" ])
				
				// resize "" "100"
				// resize "+Alt" "25"
				// resize "+Ctrl" "300";				
			};
		};
	};
}
