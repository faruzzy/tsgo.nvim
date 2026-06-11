local M = {}

local state = {
  client_name = "tsgo",
  auto_enable = true,
}

function M.configure(opts)
  state = vim.tbl_deep_extend("force", state, opts or {})
end

function M.enable(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr, name = state.client_name })) do
    if client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint, bufnr) then
      pcall(vim.lsp.inlay_hint.enable, true, { bufnr = bufnr })
      return true
    end
  end

  return false
end

function M.disable(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if #vim.lsp.get_clients({ bufnr = bufnr, name = state.client_name }) == 0 then
    return false
  end

  pcall(vim.lsp.inlay_hint.enable, false, { bufnr = bufnr })
  return true
end

function M.toggle(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr })
  if enabled then
    return M.disable(bufnr) and false or enabled
  end

  return M.enable(bufnr)
end

function M.on_attach(client, bufnr)
  if state.auto_enable and client.name == state.client_name then
    M.enable(bufnr)
  end
end

return M
