{ inputs, withSystem, ... }: {
  # LazyVim manages plugins at runtime with lazy.nvim. Nix supplies Neovim,
  # the configuration, and the language tooling that Mason would otherwise
  # download.
  perSystem = { pkgs, ... }:
  let
    # Neovim ships only English spell files and would otherwise download
    # Danish on first use. Compile them from the hunspell dictionary instead.
    danishSpell = pkgs.runCommand "nvim-spell-da" {
      nativeBuildInputs = [ pkgs.neovim-unwrapped ];
    } ''
      mkdir -p $out/spell
      HOME=$TMPDIR nvim --headless --clean \
        -c "mkspell $out/spell/da ${pkgs.hunspellDicts.da_DK}/share/hunspell/da_DK" \
        -c "qall!"
      test -f $out/spell/da.utf-8.spl
    '';
  in
  {
    packages.myNeovim = inputs.wrapper-modules.wrappers.neovim.wrap {
      inherit pkgs;

      settings.config_directory = ../../config/nvim;

      # config/nvim/lua/config/lazy.lua adds this directory to the runtimepath.
      env.NVIM_SPELL_DIR = "${danishSpell}";

      runtimePkgs = with pkgs; [
        # lazy.nvim, LazyVim, and nvim-treesitter
        git
        curl
        ripgrep
        fd
        lazygit
        tree-sitter

        # LazyVim defaults
        lua-language-server
        stylua
        shfmt

        # C# and .NET
        dotnet-sdk
        omnisharp-roslyn
        csharpier

        # Markdown
        marksman
        markdownlint-cli2
        markdown-toc

        # Python
        pyright
        ruff
      ];
    };
  };

  flake.darwinModules.neovim = { pkgs, ... }: {
    environment.systemPackages = [
      (withSystem pkgs.stdenv.hostPlatform.system ({ self', ... }: self'.packages.myNeovim))
    ];

    environment.variables.EDITOR = "nvim";
  };
}
