local util = require("tsgo.util")

local M = {}

local DEFAULT_TS_FILETYPES = {
  javascript = true,
  javascriptreact = true,
  ["javascript.jsx"] = true,
  typescript = true,
  typescriptreact = true,
  ["typescript.tsx"] = true,
}

local function merge(defaults, opts)
  return vim.tbl_deep_extend("force", defaults, opts or {})
end

local state = {
  client_name = "tsgo",
  timeout_ms = 2500,
  notify = true,
  format_after_imports = false,
  filetypes = DEFAULT_TS_FILETYPES,
}

local function notify(message, level)
  if state.notify then
    vim.notify(message, level or vim.log.levels.INFO, { title = "tsgo.nvim" })
  end
end

local function current_bufnr(bufnr)
  if bufnr and bufnr ~= 0 then
    return bufnr
  end
  return vim.api.nvim_get_current_buf()
end

local function is_ts_buffer(bufnr)
  local filetype = vim.bo[bufnr].filetype
  return state.filetypes[filetype] == true
end

local function is_tsgo_client_name(name)
  return name == "tsgo" or name:match("^tsgo[._-]") ~= nil
end

local function tsgo_clients(bufnr)
  local clients = vim.lsp.get_clients({ bufnr = bufnr, name = state.client_name })
  if #clients > 0 then
    return clients
  end

  return vim.tbl_filter(function(client)
    return is_tsgo_client_name(client.name)
  end, vim.lsp.get_clients({ bufnr = bufnr }))
end

local function assert_ready(bufnr)
  if not is_ts_buffer(bufnr) then
    notify("Current buffer is not a TypeScript or JavaScript buffer.", vim.log.levels.WARN)
    return false
  end

  if #tsgo_clients(bufnr) == 0 then
    notify("No tsgo LSP client is attached to this buffer.", vim.log.levels.WARN)
    return false
  end

  return true
end

local function code_action_command(action)
  if type(action.command) == "table" then
    return action.command
  end

  if type(action.command) == "string" then
    return {
      command = action.command,
      arguments = action.arguments or {},
      title = action.title,
    }
  end

  return nil
end

local function apply_code_action(action, client)
  if action.edit then
    vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
  end

  if action.command then
    local command = code_action_command(action)
    if not command then
      notify("Invalid tsgo command action.", vim.log.levels.ERROR)
      return false
    end

    local response = client:request_sync("workspace/executeCommand", command, state.timeout_ms)
    if response and response.err then
      notify(response.err.message or "Failed to execute tsgo command.", vim.log.levels.ERROR)
      return false
    end

    if not response then
      notify("Timed out executing tsgo command.", vim.log.levels.ERROR)
      return false
    end
  end

  return true
end

local ADD_MISSING_IMPORTS = "source.addMissingImports"

-- TypeScript diagnostic codes the missing-import quickfix responds to.
local MISSING_NAME_CODES = {
  [2304] = true, -- Cannot find name
  [2503] = true, -- Cannot find namespace
  [2552] = true, -- Cannot find name, did you mean
  [2662] = true, -- Cannot find name, did you mean the static member
  [2663] = true, -- Cannot find name, did you mean the instance member
  [2686] = true, -- Refers to a UMD global
  [2693] = true, -- Only refers to a type, but is being used as a value
  [2749] = true, -- Refers to a value, but is being used as a type
  [18004] = true, -- No value exists in scope for the shorthand property
}

local function supports_code_action_kind(client, kind)
  local provider = client.server_capabilities.codeActionProvider
  if type(provider) ~= "table" or not provider.codeActionKinds then
    return true
  end

  for _, supported in ipairs(provider.codeActionKinds) do
    if kind == supported or vim.startswith(kind, supported .. ".") then
      return true
    end
  end

  return false
end

local function missing_name_diagnostics(client, bufnr)
  local items

  if client.server_capabilities.diagnosticProvider then
    local response = client:request_sync("textDocument/diagnostic", {
      textDocument = vim.lsp.util.make_text_document_params(bufnr),
    }, state.timeout_ms, bufnr)
    items = response and response.result and response.result.items
  end

  if not items then
    items = {}
    for _, diagnostic in ipairs(vim.diagnostic.get(bufnr)) do
      local lsp_diagnostic = diagnostic.user_data and diagnostic.user_data.lsp
      if lsp_diagnostic then
        table.insert(items, lsp_diagnostic)
      end
    end
  end

  return vim.tbl_filter(function(item)
    return MISSING_NAME_CODES[tonumber(item.code)] == true
  end, items)
end

local function import_quickfixes(client, bufnr, diagnostic)
  local response = client:request_sync("textDocument/codeAction", {
    textDocument = vim.lsp.util.make_text_document_params(bufnr),
    range = diagnostic.range,
    context = { diagnostics = { diagnostic }, only = { "quickfix" } },
  }, state.timeout_ms, bufnr)

  local fix_all, single
  for _, action in ipairs((response and response.result) or {}) do
    local title = action.title or ""
    if title == "Add all missing imports" then
      fix_all = fix_all or action
    elseif vim.startswith(title, "Add import from") or vim.startswith(title, "Update import from") then
      single = single or action
    end
  end

  return fix_all, single
end

-- tsgo does not advertise source.addMissingImports yet, so fall back to the
-- per-diagnostic import quickfixes, preferring the "Add all missing imports" fix.
local function add_missing_imports_via_quickfix(client, bufnr)
  local applied = false

  -- Each applied edit shifts positions, so diagnostics are re-fetched per pass.
  for _ = 1, 50 do
    local applied_this_pass = false

    for _, diagnostic in ipairs(missing_name_diagnostics(client, bufnr)) do
      local fix_all, single = import_quickfixes(client, bufnr, diagnostic)

      if fix_all then
        return apply_code_action(fix_all, client) or applied
      end

      if single and apply_code_action(single, client) then
        applied = true
        applied_this_pass = true
        break
      end
    end

    if not applied_this_pass then
      break
    end
  end

  return applied
end

-- Source actions apply to the whole file, so the range spans bufnr itself rather than
-- the cursor of whichever window is current
local function source_action_params(bufnr, encoding)
  local last = vim.api.nvim_buf_line_count(bufnr) - 1
  local last_line = vim.api.nvim_buf_get_lines(bufnr, last, last + 1, true)[1]

  return {
    textDocument = vim.lsp.util.make_text_document_params(bufnr),
    range = {
      start = { line = 0, character = 0 },
      ["end"] = { line = last, character = vim.lsp.util.character_offset(bufnr, last, #last_line, encoding) },
    },
  }
end

local function code_action_sync(kind, opts)
  opts = opts or {}
  local bufnr = current_bufnr(opts.bufnr)

  if not assert_ready(bufnr) then
    return false
  end

  local clients = tsgo_clients(bufnr)
  local applied = false

  for _, client in ipairs(clients) do
    if kind == ADD_MISSING_IMPORTS and not supports_code_action_kind(client, kind) then
      local ok = add_missing_imports_via_quickfix(client, bufnr)
      applied = ok or applied
      if ok and not opts.apply_all then
        return true
      end
    else
      local params = source_action_params(bufnr, client.offset_encoding or "utf-16")
      params.context = {
        diagnostics = {},
        only = { kind },
      }

      local response = client:request_sync("textDocument/codeAction", params, state.timeout_ms, bufnr)

      if response and response.err then
        notify(response.err.message or ("Code action failed: " .. kind), vim.log.levels.ERROR)
      end

      for _, action in ipairs((response and response.result) or {}) do
        if action.kind and action.kind:find(kind, 1, true) == 1 then
          local ok = apply_code_action(action, client)
          applied = ok or applied
          if ok and not opts.apply_all then
            return true
          end
        end
      end
    end
  end

  if not applied and opts.notify ~= false then
    notify("No code action available for " .. kind .. ".", vim.log.levels.INFO)
  end

  return applied
end

local function run_many(kinds, opts)
  opts = opts or {}
  local did_apply = false

  for _, kind in ipairs(kinds) do
    did_apply = code_action_sync(kind, merge(opts, { notify = false })) or did_apply
  end

  if opts.format == true or (opts.format == nil and state.format_after_imports) then
    vim.lsp.buf.format({
      bufnr = current_bufnr(opts.bufnr),
      filter = function(client)
        return client.name == state.client_name
      end,
      timeout_ms = state.timeout_ms,
    })
  end

  if opts.notify ~= false then
    if did_apply then
      notify("Imports cleaned.")
    else
      notify("No import cleanup actions were available.")
    end
  end

  return did_apply
end

function M.configure(opts)
  opts = opts or {}
  state = merge(state, {
    client_name = opts.client_name,
    timeout_ms = opts.timeout_ms,
    notify = opts.notify,
    format_after_imports = opts.format_after_imports,
    filetypes = opts.filetypes,
  })
end

function M.organize_imports(opts)
  return code_action_sync("source.organizeImports", opts)
end

function M.add_missing_imports(opts)
  return code_action_sync("source.addMissingImports", opts)
end

function M.remove_unused(opts)
  return code_action_sync("source.removeUnusedImports", opts)
end

function M.fix_all(opts)
  return code_action_sync("source.fixAll", opts)
end

function M.sort_imports(opts)
  return code_action_sync("source.sortImports", opts)
end

function M.imports(opts)
  return run_many({
    "source.addMissingImports",
    "source.removeUnusedImports",
    "source.organizeImports",
  }, opts)
end

function M.source_definition(opts)
  opts = opts or {}
  local bufnr = current_bufnr(opts.bufnr)

  if not assert_ready(bufnr) then
    return
  end

  -- The position comes from a cursor, so it needs a window that shows bufnr
  local win = util.window_for_buf(bufnr)
  if not win then
    notify("Buffer " .. bufnr .. " is not displayed in a window.", vim.log.levels.WARN)
    return
  end

  local client = tsgo_clients(bufnr)[1]
  local params = vim.lsp.util.make_position_params(win, client.offset_encoding or "utf-16")

  client:request("workspace/executeCommand", {
    command = "typescript.goToSourceDefinition",
    arguments = { params.textDocument.uri, params.position },
  }, function(err, result)
    if err or not result or vim.tbl_isempty(result) then
      vim.schedule(function()
        -- vim.lsp.buf.definition() works on the current window, so run it in win
        if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == bufnr then
          vim.api.nvim_win_call(win, vim.lsp.buf.definition)
        end
      end)
      return
    end

    vim.schedule(function()
      vim.lsp.util.show_document(result[1], client.offset_encoding, { focus = true })
    end)
  end, bufnr)
end

return M
