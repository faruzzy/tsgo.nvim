local util = require("tsgo.util")

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

local function trigger_character(win)
  local row, col = unpack(vim.api.nvim_win_get_cursor(win))
  if col <= 0 then
    return nil
  end

  local line = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), row - 1, row, true)[1]
  local char = line:sub(col, col)
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

  -- The position comes from a cursor, so it needs a window that shows bufnr
  local win = util.window_for_buf(bufnr)
  if not win then
    vim.notify("Buffer " .. bufnr .. " is not displayed in a window.", vim.log.levels.WARN, { title = "tsgo.nvim" })
    return
  end

  local client = clients[1]
  local params = vim.lsp.util.make_position_params(win, client.offset_encoding or "utf-16")
  local char = opts.trigger_character or trigger_character(win)

  params.context = {
    triggerKind = char and trigger_kind.TriggerCharacter or trigger_kind.Invoked,
    triggerCharacter = char,
    isRetrigger = false,
  }

  client:request("textDocument/signatureHelp", params, function(err, result, ctx)
    if err then
      vim.notify(err.message or "Signature help failed.", vim.log.levels.WARN, { title = "tsgo.nvim" })
      return
    end

    -- The handler only shows help for the current buffer and anchors it to the cursor, so run it in win
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == bufnr then
      vim.api.nvim_win_call(win, function()
        signature_help_handler()(nil, result, ctx, opts.handler_opts or {})
      end)
    end
  end, bufnr)
end

return M
