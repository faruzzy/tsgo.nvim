local M = {}

local DEFAULT_ARGS = { "--lsp", "-stdio" }

local function with_args(executable, args)
  return vim.list_extend({ executable }, vim.deepcopy(args or DEFAULT_ARGS))
end

function M.resolve(opts)
  opts = opts or {}

  if opts.cmd then
    return opts.cmd
  end

  local args = opts.args or DEFAULT_ARGS
  local executable = vim.fn.exepath(opts.executable or "tsgo")
  if executable ~= "" then
    return with_args(executable, args)
  end

  return with_args(opts.executable or "tsgo", args)
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
