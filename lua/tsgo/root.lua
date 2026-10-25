local M = {}

local state = {
  project_root_markers = { "tsconfig.json", "jsconfig.json" },
  fallback_root_markers = { "package.json", ".git" },
  allow_inferred_project = false,
}

local function startpath_from_bufnr(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return vim.fn.getcwd()
  end

  return name
end

local function dirname(path)
  local stat = vim.uv.fs_stat(path)
  if stat and stat.type == "directory" then
    return path
  end

  return vim.fs.dirname(path)
end

local function find_root(path, markers)
  local marker = vim.fs.find(markers, {
    upward = true,
    path = dirname(path),
  })[1]

  return marker and vim.fs.dirname(marker) or nil
end

local function is_at_or_under(path, root)
  return path == root or path:sub(1, #root + 1) == root .. "/"
end

function M.configure(opts)
  state.project_root_markers = opts.project_root_markers or state.project_root_markers
  state.fallback_root_markers = opts.fallback_root_markers or state.fallback_root_markers
  state.allow_inferred_project = opts.allow_inferred_project == true
end

function M.find(path)
  local root = find_root(path, state.project_root_markers)
  local boundary = find_root(path, state.fallback_root_markers)
  -- A tsconfig above the package/repo boundary belongs to something else; ignore it
  if root and not (boundary and not is_at_or_under(root, boundary)) then
    return root
  end

  if state.allow_inferred_project then
    -- Loose files outside any package or repo (scratch dirs) root at their own directory
    return boundary or dirname(path)
  end

  return nil
end

function M.root_dir()
  return function(arg, on_dir)
    local path = type(arg) == "number" and startpath_from_bufnr(arg) or arg
    local root = M.find(path)

    if type(on_dir) == "function" then
      if root then
        on_dir(root)
      end
      return
    end

    return root
  end
end

return M
