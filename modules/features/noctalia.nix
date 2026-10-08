{ self, inputs, ...} : {
	perSystem = { pkgs, ...}: {
		packages.myNoctalia = inputs.wrapper-modules.wrappers.noctalia-shell.wrap {
			inherit pkgs;

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
