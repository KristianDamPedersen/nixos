-- Nix puts language servers, formatters, and linters on PATH, so Mason
-- stays off and LazyVim enables each server directly.
return {
  { "mason-org/mason.nvim", enabled = false },
  { "mason-org/mason-lspconfig.nvim", enabled = false },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- The dotnet extra also configures F#, which is not installed.
        fsautocomplete = { enabled = false },
      },
    },
  },
}
