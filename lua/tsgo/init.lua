local actions = require("tsgo.actions")
local cmd = require("tsgo.cmd")
local completion = require("tsgo.completion")
local config = require("tsgo.config")
local diagnostics = require("tsgo.diagnostics")
local inlay_hints = require("tsgo.inlay_hints")
local signature = require("tsgo.signature")
local util = require("tsgo.util")

local M = {}

local state = vim.deepcopy(config.defaults)

local function configure_lsp(opts)
  if not opts.setup_lsp then
    return
  end

  local lsp_config = {
    cmd = cmd.resolve(opts),
    filetypes = opts.filetypes,
    root_markers = opts.root_markers,
    settings = opts.settings,
  }

  if vim.lsp.config then
    vim.lsp.config(opts.client_name, lsp_config)
    vim.lsp.enable(opts.client_name)
    return
  end

  local ok, lspconfig = pcall(require, "lspconfig")
  if ok and lspconfig[opts.client_name] then
    lspconfig[opts.client_name].setup(lsp_config)
  end
end

local function user_command(name, callback, opts)
  if type(opts) == "string" then
    opts = { desc = opts }
  end

  opts = opts or {}
  opts.force = true
  vim.api.nvim_create_user_command(name, callback, opts)
end

local function create_commands()
  user_command("TsgoOrganizeImports", function()
    actions.organize_imports()
  end, "Organize imports with tsgo")

  user_command("TsgoAddMissingImports", function()
    actions.add_missing_imports()
  end, "Add missing imports with tsgo")

  user_command("TsgoRemoveUnused", function()
    actions.remove_unused()
  end, "Remove unused imports with tsgo")

  user_command("TsgoFixAll", function()
    actions.fix_all()
  end, "Run all tsgo source fixes")

  user_command("TsgoImports", function(command)
    actions.imports({ format = command.bang })
  end, {
    bang = true,
    desc = "Add missing imports, remove unused imports, and organize imports with tsgo",
  })

  user_command("TsgoSourceDefinition", function()
    actions.source_definition()
  end, "Go to source definition with tsgo when available")

  user_command("TsgoSignatureHelp", function()
    signature.help()
  end, "Show tsgo signature help with documentation")

  user_command("TsgoToggleInlayHints", function()
    local enabled = inlay_hints.toggle()
    vim.notify("Inlay hints " .. (enabled and "enabled" or "disabled"), vim.log.levels.INFO, { title = "tsgo.nvim" })
  end, "Toggle tsgo inlay hints")

  user_command("TsgoInfo", function()
    local resolved = cmd.resolve(state)
    local clients = vim.lsp.get_clients({ name = state.client_name })
    vim.notify(
      table.concat({
        "cmd: " .. table.concat(resolved, " "),
        "available: " .. tostring(cmd.available(resolved)),
        "active clients: " .. tostring(#clients),
      }, "\n"),
      vim.log.levels.INFO,
      { title = "tsgo.nvim" }
    )
  end, "Show tsgo.nvim runtime information")
end

local function map(bufnr, lhs, rhs, desc)
  if not lhs then
    return
  end

  vim.keymap.set("n", lhs, rhs, {
    buffer = bufnr,
    desc = desc,
    silent = true,
  })
end

local function create_keymaps(opts)
  if not opts.keymaps.enable then
    return
  end

  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("tsgo.nvim.keymaps", { clear = true }),
    callback = function(event)
      local client = vim.lsp.get_client_by_id(event.data.client_id)
      if not client or client.name ~= opts.client_name then
        return
      end

      map(event.buf, opts.keymaps.organize_imports, actions.organize_imports, "tsgo: organize imports")
      map(event.buf, opts.keymaps.add_missing_imports, actions.add_missing_imports, "tsgo: add missing imports")
      map(event.buf, opts.keymaps.remove_unused, actions.remove_unused, "tsgo: remove unused imports")
      map(event.buf, opts.keymaps.fix_all, actions.fix_all, "tsgo: fix all")
      map(event.buf, opts.keymaps.imports, actions.imports, "tsgo: clean imports")
      map(event.buf, opts.keymaps.imports_format, function()
        actions.imports({ format = true })
      end, "tsgo: clean imports and format")
      map(event.buf, opts.keymaps.source_definition, actions.source_definition, "tsgo: source definition")
      map(event.buf, opts.keymaps.signature_help, signature.help, "tsgo: signature help")
      map(event.buf, opts.keymaps.toggle_inlay_hints, inlay_hints.toggle, "tsgo: toggle inlay hints")
    end,
  })
end

local function create_conflict_warnings(opts)
  if not opts.warn_on_conflicts then
    return
  end

  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("tsgo.nvim.conflicts", { clear = true }),
    callback = function(event)
      diagnostics.warn_conflicts(opts.client_name, event.buf)
    end,
  })
end

local function create_inlay_hint_autocmd(opts)
  if not opts.inlay_hints.auto_enable then
    return
  end

  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("tsgo.nvim.inlay_hints", { clear = true }),
    callback = function(event)
      local client = vim.lsp.get_client_by_id(event.data.client_id)
      if client then
        inlay_hints.on_attach(client, event.buf)
      end
    end,
  })
end

function M.setup(opts)
  opts = vim.tbl_deep_extend("force", config.defaults, opts or {})
  state = opts

  actions.configure({
    client_name = opts.client_name,
    timeout_ms = opts.timeout_ms,
    notify = opts.notify,
    format_after_imports = opts.format_after_imports,
    filetypes = util.filetype_set(opts.filetypes),
  })
  completion.configure(vim.tbl_deep_extend("force", opts.completion, { client_name = opts.client_name }))
  inlay_hints.configure(vim.tbl_deep_extend("force", opts.inlay_hints, { client_name = opts.client_name }))
  signature.configure({
    client_name = opts.client_name,
    timeout_ms = opts.timeout_ms,
  })

  configure_lsp(opts)
  create_commands()
  create_conflict_warnings(opts)
  create_inlay_hint_autocmd(opts)
  create_keymaps(opts)
end

M.actions = actions
M.cmd = cmd
M.completion = completion
M.compat = require("tsgo.compat")
M.health = require("tsgo.health")
M.inlay_hints = inlay_hints
M.signature = signature

return M
