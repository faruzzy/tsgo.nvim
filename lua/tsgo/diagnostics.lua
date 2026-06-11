local constants = require("tsgo.constants")

local M = {}

local warned = {}

local function warning_key(bufnr, client_name)
  return tostring(bufnr) .. ":" .. client_name
end

function M.warn_conflicts(client_name, bufnr)
  if not bufnr or #vim.lsp.get_clients({ bufnr = bufnr, name = client_name }) == 0 then
    return
  end

  local conflicts = {}
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    if constants.conflicting_clients[client.name] then
      local key = warning_key(bufnr, client.name)
      if not warned[key] then
        warned[key] = true
        table.insert(conflicts, client.name)
      end
    end
  end

  if #conflicts > 0 then
    vim.notify(
      "Conflicting TypeScript LSP client(s) attached: " .. table.concat(conflicts, ", "),
      vim.log.levels.WARN,
      { title = "tsgo.nvim" }
    )
  end
end

return M
