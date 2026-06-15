# tsgo.nvim

VS Code-grade TypeScript ergonomics for Neovim, powered by the native `tsgo`
language server.

`tsgo` already speaks LSP, so this plugin does not wrap the server or translate
protocols. It owns the editor-experience layer around tsgo: command wrappers,
safer startup defaults, conflict warnings, health checks, and completion polish
for Neovim completion engines.

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
  inlay_hints = {
    auto_enable = true,
  },
  keymaps = {
    enable = true,
    organize_imports = "<leader>io",
    add_missing_imports = "<leader>ia",
    remove_unused = "<leader>ir",
    fix_all = "<leader>if",
    imports = "<leader>ii",
    imports_format = false,
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

## blink.cmp Polish

tsgo can return local-symbol text suggestions in places where VS Code keeps the
list focused on object members. tsgo.nvim exposes a blink.cmp patch that:

- refreshes on TypeScript trigger characters such as `.`,
- uses only LSP suggestions during member access,
- filters tsgo text/keyword noise from member lists,
- filters tsgo text noise on blank manual completion,
- uses prefix matching so `array.le` ranks as `le` instead of the whole line,
- buckets typed member completions by prefix match, so `.len` ranks `length`
  before fuzzy typo matches like `entries`,
- preserves TypeScript's LSP `sortText` ordering for blank member completion
  after just `.`,
- enables signature-help documentation so calls like `console.log(` show the
  richer docs tsgo returns.

Use it by merging the patch into your blink config:

```lua
local tsgo_blink = require("tsgo").compat.blink()

require("blink.cmp").setup(vim.tbl_deep_extend("force", {
  -- your blink config
}, tsgo_blink))
```

If you already have custom blink defaults, pass a fallback function:

```lua
local tsgo_blink = require("tsgo").compat.blink({
  completion = {
    member_prefix_sort = true, -- set false to keep pure blink/LSP sorting
  },
  show_signature_documentation = true,
  default_sources = function()
    return { "lsp", "path", "snippets", "buffer" }
  end,
  lsp_transform_items = function(ctx, items)
    return items
  end,
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
- `:TsgoSignatureHelp` requests tsgo signature help with VS Code-like context.
- `:TsgoToggleInlayHints`
- `:TsgoInfo` shows the resolved command and active tsgo clients.

The extra command is `:TsgoImports`: it chains add-missing imports,
remove-unused imports, and organize-imports into one import cleanup workflow.
Set `keymaps.imports_format` to bind the same workflow with formatting, matching
`:TsgoImports!`.

## API

```lua
local tsgo = require("tsgo")

tsgo.actions.organize_imports()
tsgo.actions.add_missing_imports()
tsgo.actions.remove_unused()
tsgo.actions.fix_all()
tsgo.actions.imports({ format = true })
tsgo.actions.source_definition()
tsgo.inlay_hints.toggle()
tsgo.signature.help()

local blink_patch = tsgo.compat.blink()
```

## Health

Run:

```vim
:checkhealth tsgo
```

The health check verifies that `tsgo` is executable, that your Neovim has the
native LSP config API, and that no conflicting TypeScript LSP clients are active.

## Inlay Hints

tsgo advertises inlay hints, but the TypeScript hint categories need to be
enabled through settings. tsgo.nvim enables a quiet VS Code-like default for
both JavaScript and TypeScript: parameter-name hints for all arguments and enum
member value hints. Variable, parameter type, property type, and function return
hints are off by default because they tend to add too much visual noise.

Override the settings if you want more type hints:

```lua
require("tsgo").setup({
  inlay_hints = {
    auto_enable = false,
  },
  settings = {
    typescript = {
      inlayHints = {
        parameterNames = { enabled = "all" },
        parameterTypes = { enabled = true },
        variableTypes = { enabled = true },
        functionLikeReturnTypes = { enabled = true },
      },
    },
  },
})
```

## Notes

Disable other TypeScript language servers for the same buffers. Running `tsgo`
beside `vtsls`, `ts_ls`, or `typescript-tools.nvim` will cause duplicate
diagnostics and competing code actions.
