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

    local response = client.request_sync("workspace/executeCommand", command, state.timeout_ms)
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

local function code_action_sync(kind, opts)
  opts = opts or {}
  local bufnr = current_bufnr(opts.bufnr)

  if not assert_ready(bufnr) then
    return false
  end

  local clients = tsgo_clients(bufnr)
  local client_by_id = {}
  for _, client in ipairs(clients) do
    client_by_id[client.id] = client
  end

  local client = clients[1]
  local params = vim.lsp.util.make_range_params(vim.api.nvim_get_current_win(), client.offset_encoding or "utf-16")
  params.context = {
    diagnostics = {},
    only = { kind },
  }

  local responses = vim.lsp.buf_request_sync(bufnr, "textDocument/codeAction", params, state.timeout_ms)
  local applied = false

  for client_id, response in pairs(responses or {}) do
    if response.error then
      notify(response.error.message or ("Code action failed: " .. kind), vim.log.levels.ERROR)
    end

    for _, action in ipairs(response.result or {}) do
      if action.kind and action.kind:find(kind, 1, true) == 1 then
        local action_client = client_by_id[client_id] or vim.lsp.get_client_by_id(client_id)

        if action_client then
          local ok = apply_code_action(action, action_client)
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
  return code_action_sync("source.addMissingImports.ts", opts)
end

function M.remove_unused(opts)
  return code_action_sync("source.removeUnused.ts", opts)
end

function M.fix_all(opts)
  return code_action_sync("source.fixAll.ts", opts)
end

function M.imports(opts)
  return run_many({
    "source.addMissingImports.ts",
    "source.removeUnused.ts",
    "source.organizeImports",
  }, opts)
end

function M.source_definition(opts)
  opts = opts or {}
  local bufnr = current_bufnr(opts.bufnr)

  if not assert_ready(bufnr) then
    return
  end

  local client = tsgo_clients(bufnr)[1]
  local params = vim.lsp.util.make_position_params(vim.api.nvim_get_current_win(), client.offset_encoding or "utf-16")

  client.request("workspace/executeCommand", {
    command = "typescript.goToSourceDefinition",
    arguments = { params.textDocument.uri, params.position },
  }, function(err, result)
    if err or not result or vim.tbl_isempty(result) then
      vim.schedule(function()
        vim.lsp.buf.definition()
      end)
      return
    end

    vim.schedule(function()
      vim.lsp.util.show_document(result[1], client.offset_encoding, { focus = true })
    end)
  end, bufnr)
end

return M
