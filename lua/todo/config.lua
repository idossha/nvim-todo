local M = {}

-- Default configuration
M.defaults = {
  db = {
    url = nil, -- Database connection URL
    check_connection = true, -- Check db connection on startup
  },
  ui = {
    width = 60,        -- Width of the todo window
    height = 20,       -- Height of the todo window
    border = "rounded", -- Border style
    highlight = {
      priority_high = "TodoHighPriority",
      priority_medium = "TodoMediumPriority",
      priority_low = "TodoLowPriority",
      completed = "TodoCompleted",
      due_date = "TodoDueDate",
      overdue = "TodoOverdue",
      tags = "TodoTags",
    },
  },
  mappings = {
    add = "a",
    delete = "d",
    complete = "c",
    edit = "e",
    tags = "t",
    priority = "p",
    due_date = "D",
    sort = "s",
    filter = "f",
    close = "q",
    help = "?",
  },
}

-- Update config with user options
function M.update(opts)
  return vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
