local constants = require("tsgo.constants")
local cmd = require("tsgo.cmd")

local M = {}

function M.check()
  vim.health.start("tsgo.nvim")

  local resolved = cmd.resolve()
  if cmd.available(resolved) then
    vim.health.ok("tsgo executable found: " .. resolved[1])
  else
    vim.health.error("tsgo executable not found", {
      "Install @typescript/native-preview.",
      "Ensure Neovim inherits the directory containing tsgo in $PATH.",
      "Or configure require('tsgo').setup({ cmd = { '/path/to/tsgo', '--lsp', '-stdio' } }).",
    })
  end

  if vim.lsp.config then
    vim.health.ok("Neovim native vim.lsp.config API is available")
  else
    vim.health.warn("vim.lsp.config is unavailable", {
      "Use Neovim 0.11+ for native LSP setup.",
      "Or configure tsgo through nvim-lspconfig and set setup_lsp = false.",
    })
  end

  local conflicts = {}
  for _, client in ipairs(vim.lsp.get_clients()) do
    if constants.conflicting_clients[client.name] then
      table.insert(conflicts, client.name)
    end
  end

  if #conflicts > 0 then
    vim.health.warn("Conflicting TypeScript LSP clients are active: " .. table.concat(conflicts, ", "), {
      "Run only one TypeScript language server per buffer.",
      "Disable vtsls, ts_ls, and typescript-tools.nvim while testing tsgo.",
    })
  else
    vim.health.ok("No conflicting TypeScript LSP clients are currently active")
  end
end

return M
