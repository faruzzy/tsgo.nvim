local M = {}

M.defaults = {
  setup_lsp = true,
  client_name = "tsgo",
  cmd = nil,
  executable = "tsgo",
  args = { "--lsp", "-stdio" },
  filetypes = {
    "javascript",
    "javascriptreact",
    "javascript.jsx",
    "typescript",
    "typescriptreact",
    "typescript.tsx",
  },
  root_markers = { "tsconfig.json", "jsconfig.json", "package.json", ".git" },
  settings = {
    typescript = {
      inlayHints = {
        parameterNames = { enabled = "literals" },
        parameterTypes = { enabled = false },
        variableTypes = { enabled = false },
        propertyDeclarationTypes = { enabled = false },
        functionLikeReturnTypes = { enabled = false },
        enumMemberValues = { enabled = true },
      },
    },
    javascript = {
      inlayHints = {
        parameterNames = { enabled = "literals" },
        parameterTypes = { enabled = false },
        variableTypes = { enabled = false },
        propertyDeclarationTypes = { enabled = false },
        functionLikeReturnTypes = { enabled = false },
        enumMemberValues = { enabled = true },
      },
    },
  },
  timeout_ms = 2500,
  notify = true,
  format_after_imports = false,
  warn_on_conflicts = true,
  completion = {
    filter_text_on_blank_prefix = true,
    filter_text_on_member = true,
    filter_keywords_on_member = true,
    member_prefix_sort = true,
    member_score_boost = 4,
  },
  signature = {
    show_documentation = true,
  },
  inlay_hints = {
    auto_enable = true,
  },
  keymaps = {
    enable = false,
    organize_imports = "<leader>io",
    add_missing_imports = "<leader>ia",
    remove_unused = "<leader>ir",
    fix_all = "<leader>if",
    imports = "<leader>ii",
    imports_format = false,
    source_definition = "gD",
    signature_help = false,
    toggle_inlay_hints = false,
  },
}

return M
