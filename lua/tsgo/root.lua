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

function M.configure(opts)
  state.project_root_markers = opts.project_root_markers or state.project_root_markers
  state.fallback_root_markers = opts.fallback_root_markers or state.fallback_root_markers
  state.allow_inferred_project = opts.allow_inferred_project == true
end

function M.find(path)
  local root = find_root(path, state.project_root_markers)
  if root then
    return root
  end

  if state.allow_inferred_project then
    return find_root(path, state.fallback_root_markers)
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
