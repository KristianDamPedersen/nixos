/*
	Tools for integrating with GitHub.

	Currently includes:
		* Github CLI (gh)
	
	Authenticate after rebuilding with:
		gh auth login
*/
{ self, inputs, ...} : {
	flake.nixosModules.github = { pkgs, ... }: {
		environment.systemPackages = [ pkgs.gh ];
	};
}
