local M = {}

-- Default configuration
M.config = {
  storage = {
    path = vim.fn.stdpath("data") .. "/todo.json", -- Default path for storing todos
  },
  ui = {
    width = 0.8,        -- Width of the todo window (80% of screen)
    height = 0.8,       -- Height of the todo window (80% of screen)
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

-- Setup function
function M.setup(opts)
  -- Merge user options with defaults
  if opts then
    M.config = vim.tbl_deep_extend("force", M.config, opts)
  end
  
  -- Load components
  local storage = require("todo.storage")
  local commands = require("todo.commands")
  
  -- Initialize storage
  storage.init()
  
  -- Set up plugin commands
  commands.setup()
  
  -- Set up highlights
  vim.cmd [[
    highlight default link TodoHighPriority Error
    highlight default link TodoMediumPriority WarningMsg
    highlight default link TodoLowPriority Comment
    highlight default link TodoCompleted Comment
    highlight default link TodoDueDate String
    highlight default link TodoOverdue Error
    highlight default link TodoTags Identifier
  ]]
  
  vim.notify("Todo.nvim initialized successfully!", vim.log.levels.INFO)
end

-- Export API functions that will be used by commands
-- Export API functions that will be used by commands
M.open = function()
  require("todo.ui").open()
end

M.add = function(opts)
  require("todo.ui").add_todo(opts)
end

M.complete = function(id)
  require("todo.storage").complete_todo(id)
  -- Refresh UI if open
  if require("todo.ui").is_open() then
    require("todo.ui").refresh()
  end
end

M.delete = function(id)
  require("todo.storage").delete_todo(id)
  -- Refresh UI if open
  if require("todo.ui").is_open() then
    require("todo.ui").refresh()
  end
end

M.stats = function()
  require("todo.stats").show()
end

return M
