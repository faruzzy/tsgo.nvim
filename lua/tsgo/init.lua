local actions = require("tsgo.actions")

local M = {}

local defaults = {
  setup_lsp = true,
  client_name = "tsgo",
  cmd = nil,
  filetypes = {
    "javascript",
    "javascriptreact",
    "javascript.jsx",
    "typescript",
    "typescriptreact",
    "typescript.tsx",
  },
  root_markers = { "tsconfig.json", "jsconfig.json", "package.json", ".git" },
  timeout_ms = 2500,
  notify = true,
  format_after_imports = false,
  keymaps = {
    enable = false,
    organize_imports = "<leader>io",
    add_missing_imports = "<leader>ia",
    remove_unused = "<leader>ir",
    fix_all = "<leader>if",
    imports = "<leader>ii",
    source_definition = "gD",
  },
}

local function tsgo_cmd()
  local executable = vim.fn.exepath("tsgo")
  if executable ~= "" then
    return { executable, "--lsp", "-stdio" }
  end

  if vim.fn.executable("mise") == 1 then
    local result = vim.system({ "mise", "which", "tsgo" }, { text = true }):wait()
    local mise_executable = result.stdout and vim.trim(result.stdout) or ""
    if result.code == 0 and mise_executable ~= "" then
      return { mise_executable, "--lsp", "-stdio" }
    end
  end

  return { "tsgo", "--lsp", "-stdio" }
end

local function configure_lsp(opts)
  if not opts.setup_lsp then
    return
  end

  local config = {
    cmd = opts.cmd or tsgo_cmd(),
    filetypes = opts.filetypes,
    root_markers = opts.root_markers,
  }

  if vim.lsp.config then
    vim.lsp.config(opts.client_name, config)
    vim.lsp.enable(opts.client_name)
    return
  end

  local ok, lspconfig = pcall(require, "lspconfig")
  if ok and lspconfig[opts.client_name] then
    lspconfig[opts.client_name].setup(config)
  end
end

local function user_command(name, callback, opts)
  if type(opts) == "string" then
    opts = { desc = opts }
  end

  vim.api.nvim_create_user_command(name, callback, opts or {})
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
end

local function map(bufnr, lhs, rhs, desc)
  if not lhs or lhs == false then
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
      map(event.buf, opts.keymaps.source_definition, actions.source_definition, "tsgo: source definition")
    end,
  })
end

local function filetype_set(filetypes)
  local result = {}

  for _, filetype in ipairs(filetypes) do
    result[filetype] = true
  end

  return result
end

function M.setup(opts)
  opts = vim.tbl_deep_extend("force", defaults, opts or {})

  actions.configure({
    client_name = opts.client_name,
    timeout_ms = opts.timeout_ms,
    notify = opts.notify,
    format_after_imports = opts.format_after_imports,
    filetypes = filetype_set(opts.filetypes),
  })

  configure_lsp(opts)
  create_commands()
  create_keymaps(opts)
end

M.actions = actions

return M
