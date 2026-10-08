/*
	Password manager configuration

	I currently use 1Password.

	Includes:
		* 1Password GUI
		* 1Password CLI

	Authenticate after rebuilding with:
		gh auth logi
*/
{ self, inputs, ...} : {
	flake.nixosModules.passwordManager = { pkgs, ... }: {
                                       programs._1password.enable = true;
                                       programs._1password-gui.enable = true;
	};
}
