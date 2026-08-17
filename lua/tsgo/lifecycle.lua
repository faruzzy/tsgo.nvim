local M = {}

local state = {
  client_name = "tsgo",
  setup_lsp = true,
}

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "tsgo.nvim" })
end

local function clients()
  return vim.lsp.get_clients({ name = state.client_name })
end

local function client_ids(active)
  return vim.tbl_map(function(client)
    return client.id
  end, active)
end

local function set_enabled(enabled)
  if state.setup_lsp and vim.lsp.enable then
    vim.lsp.enable(state.client_name, enabled)
    return true
  end

  return false
end

function M.configure(opts)
  state.client_name = opts.client_name or state.client_name
  state.setup_lsp = opts.setup_lsp
end

function M.stop(opts)
  opts = opts or {}

  local active = clients()
  set_enabled(false)

  if #active == 0 then
    notify("No active " .. state.client_name .. " clients.")
    return 0
  end

  vim.lsp.stop_client(client_ids(active), opts.force == true)
  notify("Stopped " .. tostring(#active) .. " " .. state.client_name .. " client(s).")
  return #active
end

function M.start()
  if not set_enabled(true) then
    notify("tsgo auto-start is not managed by tsgo.nvim.", vim.log.levels.WARN)
    return false
  end

  notify("Enabled " .. state.client_name .. " auto-start.")
  return true
end

function M.restart(opts)
  opts = opts or {}
  M.stop({ force = opts.force })

  vim.defer_fn(function()
    M.start()
  end, opts.delay_ms or 500)
end

return M
