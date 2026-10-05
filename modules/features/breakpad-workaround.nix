{ self, inputs, ... }:
let
	overlay = final: prev: {
		breakpad = prev.breakpad.overrideAttrs (old: {
			postPatch = (old.postPatch or "") + ''
        substituteInPlace src/processor/module_factory.h \
          --replace-fail \
          "const string& name) const {
    return new BasicSourceLineResolver::Module(name);
  }" \
          "const string& name) const;" \
          --replace-fail \
          "const string& name) const {
    return new FastSourceLineResolver::Module(name);
  }" \
          "const string& name) const;"

        cat >> src/processor/basic_source_line_resolver.cc <<'CPP'

namespace google_breakpad {
BasicSourceLineResolver::Module* BasicModuleFactory::CreateModule(
    const string& name) const {
  return new BasicSourceLineResolver::Module(name);
}
}
CPP

        cat >> src/processor/fast_source_line_resolver.cc <<'CPP'

namespace google_breakpad {
FastSourceLineResolver::Module* FastModuleFactory::CreateModule(
    const string& name) const {
  return new FastSourceLineResolver::Module(name);
}
}
CPP
      '';
		});
	};
in
{
	flake.overlays.breakpadWorkaround = overlay;
	perSystem = { system, pkgs, ... }: {
		_module.args.pkgs = import inputs.nixpkgs {
			inherit system;
			overlays = [ overlay ];
		};

		# Allow nixpkgs#package to resolve through this flake.
		legacyPackages = pkgs;
	};

	flake.nixosModules.breakpadWorkaround = { lib, ... }: {
		nixpkgs.overlays = [ overlay ];
		nix.registry.nixpkgs.to = lib.mkForce {
			type = "path";
			path = self.outPath;
		};
	};
}
