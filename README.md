# tsgo.nvim

Small Neovim companion plugin for the native TypeScript `tsgo` language server.

`tsgo` already speaks LSP, so this plugin does not wrap the server or translate
protocols. It adds the convenience commands you might miss when moving from
`nvim-vtsls`: organize imports, add missing imports, remove unused imports, fix
all, and a combined import hygiene command.

## Requirements

- Neovim 0.10+.
- The `tsgo` binary from `@typescript/native-preview`.

```sh
npm install -g @typescript/native-preview
```

## Install

With lazy.nvim:

```lua
{
  "faruzzy/tsgo.nvim",
  opts = {
    keymaps = { enable = true },
  },
}
```

For a local checkout:

```lua
{
  dir = "~/github/tsgo.nvim",
  opts = {
    keymaps = { enable = true },
  },
}
```

## Setup

```lua
require("tsgo").setup({
  keymaps = {
    enable = true,
    organize_imports = "<leader>io",
    add_missing_imports = "<leader>ia",
    remove_unused = "<leader>ir",
    fix_all = "<leader>if",
    imports = "<leader>ii",
    source_definition = "gD",
  },
})
```

On Neovim 0.11+, `setup()` also registers and enables the LSP config:

```lua
vim.lsp.config("tsgo", {
  cmd = { "tsgo", "--lsp", "-stdio" },
  filetypes = {
    "javascript",
    "javascriptreact",
    "javascript.jsx",
    "typescript",
    "typescriptreact",
    "typescript.tsx",
  },
  root_markers = { "tsconfig.json", "jsconfig.json", "package.json", ".git" },
})
vim.lsp.enable("tsgo")
```

If you already configure `tsgo` elsewhere, disable that part:

```lua
require("tsgo").setup({
  setup_lsp = false,
  keymaps = { enable = true },
})
```

When `cmd` is omitted, tsgo.nvim resolves `tsgo` with `vim.fn.exepath()`, then
falls back to the plain `tsgo` command. This works for npm, Homebrew, nvm, fnm,
asdf, mise, Volta, and other installers as long as Neovim inherits the directory
containing `tsgo` in `$PATH`.

If Neovim starts from a GUI or project shell where `tsgo` is not on `$PATH`,
provide an explicit command:

```lua
require("tsgo").setup({
  cmd = { "/absolute/path/to/tsgo", "--lsp", "-stdio" },
})
```

## Commands

- `:TsgoOrganizeImports`
- `:TsgoAddMissingImports`
- `:TsgoRemoveUnused`
- `:TsgoFixAll`
- `:TsgoImports`
- `:TsgoImports!` cleans imports and formats afterward.
- `:TsgoSourceDefinition` tries the TypeScript source-definition command and
  falls back to standard LSP definition.

The extra command is `:TsgoImports`: it chains add-missing imports,
remove-unused imports, and organize-imports into one import cleanup workflow.

## API

```lua
local tsgo = require("tsgo")

tsgo.actions.organize_imports()
tsgo.actions.add_missing_imports()
tsgo.actions.remove_unused()
tsgo.actions.fix_all()
tsgo.actions.imports({ format = true })
tsgo.actions.source_definition()
```

## Notes

Disable other TypeScript language servers for the same buffers. Running `tsgo`
beside `vtsls`, `ts_ls`, or `typescript-tools.nvim` will cause duplicate
diagnostics and competing code actions.
