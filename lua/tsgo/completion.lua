local util = require("tsgo.util")

local M = {}

local state = {
  client_name = "tsgo",
  filter_text_on_blank_prefix = true,
  filter_text_on_member = true,
  filter_keywords_on_member = true,
  member_prefix_sort = true,
  member_score_boost = 4,
}

function M.configure(opts)
  state = vim.tbl_deep_extend("force", state, opts or {})
end

local function label_starts_with_prefix(label, prefix)
  return tostring(label or ""):lower():sub(1, #prefix) == prefix
end

local function apply_member_prefix_sort(item, prefix)
  local bucket = label_starts_with_prefix(item.label, prefix) and "0" or "1"
  item.sortText = bucket .. ":" .. tostring(item.sortText or item.label or "")
end

function M.transform_items(ctx, items, opts)
  opts = opts or {}
  local text_kind = vim.lsp.protocol.CompletionItemKind.Text
  local keyword_kind = vim.lsp.protocol.CompletionItemKind.Keyword
  local property_kind = vim.lsp.protocol.CompletionItemKind.Property
  local member_prefix = util.member_prefix_from_context(ctx)
  local completing_member = member_prefix ~= nil
  local blank_prefix = util.has_blank_prefix()
  local member_prefix_sort = opts.member_prefix_sort
  if member_prefix_sort == nil then
    member_prefix_sort = state.member_prefix_sort
  end
  local seen = {}
  local result = {}

  for _, item in ipairs(items) do
    local is_tsgo = item.client_name == state.client_name
    local keep = true

    if is_tsgo and completing_member then
      if state.filter_text_on_member and item.kind == text_kind then
        keep = false
      elseif state.filter_keywords_on_member and item.kind == keyword_kind then
        keep = false
      elseif member_prefix and #member_prefix == 1 and item.kind == property_kind then
        item.score_offset = (item.score_offset or 0) - 4
      elseif state.member_score_boost ~= 0 then
        item.score_offset = (item.score_offset or 0) + state.member_score_boost
      end

      if keep and member_prefix_sort and member_prefix and member_prefix ~= "" then
        apply_member_prefix_sort(item, member_prefix:lower())
      end
    end

    if keep and is_tsgo and blank_prefix and state.filter_text_on_blank_prefix and item.kind == text_kind then
      keep = false
    end

    local key = item.label .. (item.kind or "")
    if keep and not seen[key] then
      seen[key] = true
      table.insert(result, item)
    end
  end

  return result
end

function M.blink_sources_default(fallback)
  return function()
    if util.is_member_completion() then
      return { "lsp" }
    end

    if fallback then
      return fallback()
    end

    return { "lsp", "path", "snippets", "buffer" }
  end
end

function M.member_prefix_first(a, b)
  local prefix = util.member_prefix()
  if not prefix or prefix == "" then
    return nil
  end

  prefix = prefix:lower()

  local a_label = tostring(a.label or ""):lower()
  local b_label = tostring(b.label or ""):lower()
  local a_starts_with_prefix = a_label:sub(1, #prefix) == prefix
  local b_starts_with_prefix = b_label:sub(1, #prefix) == prefix

  if a_starts_with_prefix ~= b_starts_with_prefix then
    return a_starts_with_prefix
  end

  return nil
end

function M.blink_sorts(opts)
  opts = opts or {}

  local member_prefix = util.member_prefix()
  if member_prefix and member_prefix ~= "" then
    if opts.member_prefix_sort ~= false then
      return { "exact", M.member_prefix_first, "score", "sort_text", "label", "kind" }
    end

    return { "exact", "score", "sort_text", "label", "kind" }
  end

  return { "exact", "sort_text", "label", "score", "kind" }
end

function M.blink_patch(opts)
  opts = opts or {}
  local show_signature_documentation = opts.show_signature_documentation
  if show_signature_documentation == nil then
    show_signature_documentation = true
  end

  local lsp_transform_items = opts.lsp_transform_items
  local completion_opts = opts.completion or {}
  local member_prefix_sort = completion_opts.member_prefix_sort
  if member_prefix_sort == nil then
    member_prefix_sort = opts.prioritize_member_prefix
  end
  if member_prefix_sort == nil then
    member_prefix_sort = true
  end

  return {
    completion = {
      keyword = {
        range = "prefix",
      },
      trigger = {
        show_on_trigger_character = true,
        show_on_accept_on_trigger_character = true,
        show_on_insert_on_trigger_character = true,
      },
    },
    signature = {
      enabled = true,
      window = {
        show_documentation = show_signature_documentation,
      },
    },
    fuzzy = {
      sorts = function()
        return M.blink_sorts({ member_prefix_sort = member_prefix_sort })
      end,
    },
    sources = {
      default = M.blink_sources_default(opts.default_sources),
      providers = {
        lsp = {
          fallbacks = {},
          transform_items = function(ctx, items)
            if lsp_transform_items then
              items = lsp_transform_items(ctx, items)
            end

            return M.transform_items(ctx, items, { member_prefix_sort = member_prefix_sort })
          end,
        },
      },
    },
  }
end

return M
