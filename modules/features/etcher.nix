{ withSystem, ... }: {
  perSystem = { pkgs, ... }: {
    packages.etcher = pkgs.stdenv.mkDerivation rec {
      pname = "balena-etcher";
      version = "2.1.9";

      src = pkgs.fetchurl {
        url = "https://github.com/balena-io/etcher/releases/download/v${version}/balena-etcher_${version}_amd64.deb";
        hash = "sha256-fg0OCYbl0PPZwDpMAAT5iRI1FQ4NqZ+gvDMtjAPxpMA=";
      };

      nativeBuildInputs = with pkgs; [
        dpkg
        autoPatchelfHook
        makeWrapper
        wrapGAppsHook3
      ];
      buildInputs = with pkgs; [
        alsa-lib
        at-spi2-atk
        cairo
        cups
        dbus
        expat
        glib
        gtk3
        libdrm
        libgbm
        libusb1
        libx11
        libxcb
        libxcomposite
        libxdamage
        libxext
        libxfixes
        libxkbcommon
        libxrandr
        nspr
        nss
        pango
        stdenv.cc.cc.lib
        systemd
      ];

      unpackPhase = "dpkg-deb --fsys-tarfile $src | tar --extract --no-same-permissions";
      dontBuild = true;
      dontWrapGApps = true;
      installPhase = ''
        runHook preInstall
        mkdir -p $out
        cp -r usr/lib usr/share $out/
        mkdir -p $out/bin
        ln -sfn balena-etcher $out/lib/balena-etcher/balenaEtcher
        runHook postInstall
      '';
      preFixup = ''
        makeWrapper $out/lib/balena-etcher/balena-etcher $out/bin/balena-etcher \
          "''${gappsWrapperArgs[@]}" \
          --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.util-linux pkgs.coreutils ]}
      '';

      meta = {
        description = "Flash OS images to SD cards and USB drives";
        homepage = "https://github.com/balena-io/etcher";
        license = pkgs.lib.licenses.asl20;
        platforms = [ "x86_64-linux" ];
        mainProgram = "balena-etcher";
      };
    };
  };

  flake.nixosModules.etcher = { pkgs, ... }: {
    environment.systemPackages = [
      (withSystem pkgs.stdenv.hostPlatform.system ({ self', ... }: self'.packages.etcher))
    ];
  };
}
