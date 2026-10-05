/*
	Git
*/
{ self, inputs, ...} : {
	flake.nixosModules.git = { pkgs, ... }: {
		programs.git.enable = true;
	};
}
