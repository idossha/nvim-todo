local M = {}

M.default_config = {
  mappings = {
    open = "<leader>to",
    add = "<leader>ta",
    delete = "d",
    complete = "c",
    edit = "e",
    tags = "t",
    priority = "p",
    due_date = "D",
    sort = "s",
    filter = "f",
    close = "q",
  },
  -- ... rest of your config ...
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.default_config, opts or {})
  return M.config
end

return M 