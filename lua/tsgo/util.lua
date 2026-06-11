local M = {}

function M.filetype_set(filetypes)
  local result = {}

  for _, filetype in ipairs(filetypes or {}) do
    result[filetype] = true
  end

  return result
end

function M.is_member_completion()
  return M.member_prefix() ~= nil
end

function M.member_prefix_at(line, col)
  if col < 0 then
    return nil
  end

  local before_cursor = line:sub(1, math.min(#line, col))
  local prefix = before_cursor:match("%.([%w_$]*)$")
  if prefix ~= nil then
    if prefix == "" then
      local suffix = line:sub(col + 1):match("^([%w_$]+)")
      if suffix then
        return suffix
      end
    end

    return prefix
  end

  before_cursor = line:sub(1, math.min(#line, col + 1))
  prefix = before_cursor:match("%.([%w_$]*)$")
  if prefix ~= nil then
    return prefix
  end

  if line:sub(col + 1, col + 1) == "." then
    return ""
  end

  return nil
end

function M.member_prefix_from_context(ctx)
  if ctx and ctx.line and ctx.cursor and ctx.cursor[2] then
    return M.member_prefix_at(ctx.line, ctx.cursor[2])
  end

  return M.member_prefix()
end

function M.member_prefix()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  local line = vim.api.nvim_get_current_line()

  return M.member_prefix_at(line, col)
end

function M.has_blank_prefix()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  return vim.api.nvim_get_current_line():sub(1, col):match("^%s*$") ~= nil
end

return M
