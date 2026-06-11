local M = {}

local state = {
  client_name = "tsgo",
  timeout_ms = 2500,
}

local trigger_kind = {
  Invoked = 1,
  TriggerCharacter = 2,
}

local function signature_help_handler()
  return vim.lsp.handlers.signature_help or vim.lsp.handlers["textDocument/signatureHelp"]
end

function M.configure(opts)
  state = vim.tbl_deep_extend("force", state, opts or {})
end

local function trigger_character()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  if col <= 0 then
    return nil
  end

  local char = vim.api.nvim_get_current_line():sub(col, col)
  if char == "(" or char == "," then
    return char
  end

  return nil
end

function M.help(opts)
  opts = opts or {}

  local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({
    bufnr = bufnr,
    name = opts.client_name or state.client_name,
    method = "textDocument/signatureHelp",
  })

  if #clients == 0 then
    return vim.lsp.buf.signature_help()
  end

  local client = clients[1]
  local params = vim.lsp.util.make_position_params(vim.api.nvim_get_current_win(), client.offset_encoding or "utf-16")
  local char = opts.trigger_character or trigger_character()

  params.context = {
    triggerKind = char and trigger_kind.TriggerCharacter or trigger_kind.Invoked,
    triggerCharacter = char,
    isRetrigger = false,
  }

  client.request("textDocument/signatureHelp", params, function(err, result, ctx)
    if err then
      vim.notify(err.message or "Signature help failed.", vim.log.levels.WARN, { title = "tsgo.nvim" })
      return
    end

    signature_help_handler()(nil, result, ctx, opts.handler_opts or {})
  end, bufnr)
end

return M
