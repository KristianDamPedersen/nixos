{ inputs, withSystem, ... }: {
  # LazyVim manages plugins at runtime with lazy.nvim. Nix supplies Neovim,
  # the configuration, and the language tooling that Mason would otherwise
  # download.
  perSystem = { pkgs, ... }: {
    packages.myNeovim = inputs.wrapper-modules.wrappers.neovim.wrap {
      inherit pkgs;

      settings.config_directory = ../../config/nvim;

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
