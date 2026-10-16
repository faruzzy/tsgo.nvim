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

function M.object_property_prefix_at(line, col)
  if col < 0 then
    return nil
  end

  local before_cursor = line:sub(1, math.min(#line, col))
  if before_cursor:match("[:%.]%s*[%w_$]*$") then
    return nil
  end

  return before_cursor:match("^%s*([%w_$]*)$") or before_cursor:match("[{,]%s*([%w_$]*)$")
end

-- The line patterns alone also match any statement that starts with an
-- identifier, so confirm with treesitter that the cursor is inside an object.
-- Returns true when treesitter can't tell (no parser, or a parse error).
local function inside_object(bufnr, row, col)
  local ok, node = pcall(vim.treesitter.get_node, {
    bufnr = bufnr,
    pos = { row, math.max(col - 1, 0) },
    ignore_injections = false,
  })
  if not ok or not node then
    return true
  end

  while node do
    local node_type = node:type()
    if node_type == "object" or node_type == "object_pattern" or node_type == "ERROR" then
      return true
    end
    node = node:parent()
  end

  return false
end

function M.object_property_prefix_from_context(ctx)
  local bufnr, row, col, line
  if ctx and ctx.line and ctx.cursor and ctx.cursor[2] then
    bufnr, row, col, line = ctx.bufnr or 0, ctx.cursor[1] - 1, ctx.cursor[2], ctx.line
  else
    local cursor = vim.api.nvim_win_get_cursor(0)
    bufnr, row, col, line = 0, cursor[1] - 1, cursor[2], vim.api.nvim_get_current_line()
  end

  local prefix = M.object_property_prefix_at(line, col)
  if prefix == nil or not inside_object(bufnr, row, col) then
    return nil
  end

  return prefix
end

function M.is_object_property_completion()
  return M.object_property_prefix_from_context() ~= nil
end

function M.word_prefix()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  local before_cursor = vim.api.nvim_get_current_line():sub(1, col)
  return before_cursor:match("([%w_$]+)$")
end

return M
