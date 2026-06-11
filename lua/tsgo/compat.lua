local M = {}

function M.blink(opts)
  return require("tsgo.completion").blink_patch(opts)
end

return M
