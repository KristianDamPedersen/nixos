{ inputs, withSystem, ... }: {
  perSystem =
    {
      pkgs,
      lib,
      self',
      ...
    }:
    let
      doomDir =
        pkgs.runCommand "personal-doom-config"
          {
            nativeBuildInputs = [
              pkgs.bash
              pkgs.python3
            ];
          }
          ''
            mkdir -p "$out"
            cp -R ${../../config/doom}/. "$out/"
            chmod -R u+w "$out"
            chmod +x "$out/bin/"*
            patchShebangs "$out/bin"
          '';

      runtimeTools = with pkgs; [
        bash
        coreutils
        diffutils
        findutils
        git
        gh
        openssh
        gnupg
        secretspec
        python3
        util-linux
        curl
        fd
        ripgrep
        notmuch
        lieer
        pandoc
        shellcheck
        elan
        xdg-utils
        wl-clipboard
        nil
        nixfmt
        rust-analyzer
        rustc
        cargo
        rustfmt
        clippy
        nodejs
        typescript
        typescript-language-server
      ];

      doomBuildPkgs = import inputs.nixpkgs {
        system = pkgs.stdenv.hostPlatform.system;
        config.problems.handlers.org-timeblock.broken = "warn";
      };

      doomPackages = inputs.doom.lib.doomFromPackages doomBuildPkgs {
        doomDir = doomDir;
        doomLocalDir = "~/.local/share/doom-nix";
        emacs = pkgs.emacs-pgtk;
        extraBinPackages = runtimeTools;

        extraPackages = epkgs: [
          (epkgs.treesit-grammars.with-grammars (grammars: [
            grammars.tree-sitter-nix
            grammars.tree-sitter-rust
            grammars.tree-sitter-javascript
            grammars.tree-sitter-jsdoc
            grammars.tree-sitter-typescript
            grammars.tree-sitter-tsx
          ]))
        ];

        emacsPackageOverrides = final: prev: {
          ghostel = prev.ghostel.overrideAttrs {
            zigDeps = pkgs.zig_0_16.fetchDeps {
              pname = "ghostel";
              version = "0.50.0";
              src = prev.ghostel.src;
              fetchAll = true;

              # Zig dependency hash reported by the build.
              hash = "sha256-87q0nSOkZaIHW8Ztgf5pR13sHNw7eQKJhu12QjRMTvA=";
            };
          };

          org-timeblock = prev.org-timeblock.overrideAttrs (old: {
            meta = (old.meta or { }) // {
              broken = false;
            };

            postPatch = (old.postPatch or "") + ''
              substituteInPlace org-timeblock.el \
                                --replace-fail "(require 'compat)" "" \
                                --replace-fail "(require 'compat-macs)" "" \
                                --replace-fail '(compat-version "29.1")' "" \
                                --replace-fail \
                                               $'(compat-defun org-fold-show-context (&optional key)\n  "Make sure point and context are visible."\n  (org-show-context key))' "" \
                               --replace-fail \
                                              "(compat-call org-fold-show-context 'agenda)" "(org-fold-show-context 'agenda)"
            '';
          });

        };

      };
    in
    {
      packages.myEmacs = doomPackages.emacsWithDoom;

      packages.emacs-kitty = pkgs.writeShellScriptBin "emacs-kitty" ''
        exec ${lib.getExe self'.packages.myKitty} \
             --class emacs \
             -o window_padding_width=0 \
             -o window_margin_width=0 \
             -o tab_bar_style=hidden \
             ${self'.packages.myEmacs}/bin/emacs -nw "$@"
      '';

      packages.emacs-kitty-desktop = pkgs.makeDesktopItem {
        name = "emacs";
        desktopName = "Emacs";
        genericName = "Text Editor";
        exec = "${self'.packages.emacs-kitty}/bin/emacs-kitty %F";
        icon = "emacs";
        terminal = false;
        categories = [
          "Development"
          "TextEditor"
        ];
        mimeTypes = [
          "text/plain"
          "text/x-org"
        ];
      };

      packages.org-sync = pkgs.writeShellApplication {
        name = "org-sync";
        runtimeInputs = [
          pkgs.python3
          pkgs.git
          pkgs.gh
        ];
        text = ''
          exec python3 ${doomDir}/bin/org-sync.py "$@"
        '';
      };
    };

  flake.nixosModules.emacs =
    { pkgs, lib, ... }:
    let
      packages = withSystem pkgs.stdenv.hostPlatform.system ({ self', ... }: self'.packages);
    in
    {
      environment.systemPackages = with pkgs; [
        packages.myEmacs
        packages.emacs-kitty
        (lib.hiPrio packages.emacs-kitty-desktop)
        packages.org-sync
        secretspec
        gnupg
        notmuch
        lieer
        python3
        rsync
        elan
      ];

      environment.sessionVariables.EDITOR = "emacs-kitty";

      xdg.mime.defaultApplications = {
        "text/plain" = [ "emacs.desktop" ];
        "text/x-org" = [ "emacs.desktop" ];
      };

      programs.gnupg.agent = {
        enable = true;
        pinentryPackage = pkgs.pinentry-gnome3;
      };

      fonts.packages = [
        pkgs.nerd-fonts.jetbrains-mono
      ];
    };

}
