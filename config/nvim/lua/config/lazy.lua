local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- This configuration lives in the Nix store, outside stdpath("config").
-- lazy.nvim resets the runtimepath at startup, so keep this directory on it.
local configdir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h")

require("lazy").setup({
  spec = {
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    { import = "lazyvim.plugins.extras.lang.dotnet" },
    { import = "lazyvim.plugins.extras.lang.markdown" },
    { import = "lazyvim.plugins.extras.lang.python" },
    { import = "plugins" },
  },
  defaults = {
    lazy = false,
    version = false,
  },
  -- The config directory is read-only.
  lockfile = vim.fn.stdpath("data") .. "/lazy-lock.json",
  install = { colorscheme = { "tokyonight", "habamax" } },
  checker = { enabled = true, notify = false },
  performance = {
    rtp = {
      -- NVIM_SPELL_DIR holds the Danish spell file built by Nix.
      paths = { configdir, vim.env.NVIM_SPELL_DIR },
      disabled_plugins = {
        "gzip",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})
