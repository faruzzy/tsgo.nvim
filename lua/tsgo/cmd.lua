local M = {}

local DEFAULT_ARGS = { "--lsp", "-stdio" }

local function with_args(executable, args)
  return vim.list_extend({ executable }, vim.deepcopy(args or DEFAULT_ARGS))
end

-- Neovim launched outside a mise-activated shell (e.g. from a GUI) won't have
-- mise-installed npm globals on PATH, so look for tsgo there explicitly.
local function mise_executable(name)
  if vim.fn.executable("mise") == 1 then
    local result = vim.system({ "mise", "which", name }, { text = true }):wait()
    local path = result.stdout and vim.trim(result.stdout) or ""
    if result.code == 0 and path ~= "" then
      return path
    end
  end

  local data_dir = vim.env.MISE_DATA_DIR or (vim.fn.expand("~") .. "/.local/share/mise")
  local installs = vim.fn.glob(data_dir .. "/installs/node/*/bin/" .. name, false, true)
  table.sort(installs)
  for index = #installs, 1, -1 do
    if vim.fn.executable(installs[index]) == 1 then
      return installs[index]
    end
  end

  return nil
end

function M.resolve(opts)
  opts = opts or {}

  if opts.cmd then
    return opts.cmd
  end

  local args = opts.args or DEFAULT_ARGS
  local name = opts.executable or "tsgo"
  local executable = vim.fn.exepath(name)
  if executable ~= "" then
    return with_args(executable, args)
  end

  return with_args(mise_executable(name) or name, args)
end

function M.executable(cmd)
  cmd = cmd or M.resolve()
  return cmd[1]
end

function M.available(cmd)
  local executable = M.executable(cmd)
  return executable ~= nil and executable ~= "" and vim.fn.executable(executable) == 1
end

return M
