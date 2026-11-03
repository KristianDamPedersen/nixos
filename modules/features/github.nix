/*
  	Tools for integrating with GitHub.

  	Currently includes:
  		* Github CLI (gh)

  	Authenticate after rebuilding with:
  		gh auth login
*/
{ self, inputs, ... }:
let
  github = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.gh ];
  };
in
{
  flake.nixosModules.github = github;
  flake.darwinModules.github = github;
}
