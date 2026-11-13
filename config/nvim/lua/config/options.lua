-- LazyVim enables spell checking in Markdown, text, and Git commit buffers.
-- Check those buffers against both English and Danish.
vim.opt.spelllang = { "en", "da" }

-- The config directory is read-only, so keep words added with `zg` in the
-- data directory.
local spelldir = vim.fn.stdpath("data") .. "/spell"
vim.fn.mkdir(spelldir, "p")
vim.opt.spellfile = spelldir .. "/en.utf-8.add"
