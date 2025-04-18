local M = {}

-- Default configuration
M.config = {
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

-- Setup function
function M.setup(opts)
  -- Merge user options with defaults
  if opts then
    M.config = vim.tbl_deep_extend("force", M.config, opts)
  end

  -- Load components
  local db = require("todo.db")
  local schema = require("todo.schema")
  local commands = require("todo.commands")
  
  -- Check if db connection is enabled and set up
  if M.config.db.url and M.config.db.check_connection then
    if not db.check_connection() then
      vim.notify("todo.nvim: Could not connect to database. Please check configuration.", vim.log.levels.ERROR)
      return
    end
    
    -- Initialize schema if needed
    schema.init()
  else
    vim.notify("todo.nvim: Database URL not configured.", vim.log.levels.WARN)
  end
  
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
end

-- Export API functions that will be used by commands
M.open = function()
  require("todo.ui").open()
end

M.add = function(opts)
  require("todo.ui").add_todo(opts)
end

M.complete = function(id)
  require("todo.db").complete_todo(id)
  -- Refresh UI if open
  if require("todo.ui").is_open() then
    require("todo.ui").refresh()
  end
end

M.delete = function(id)
  require("todo.db").delete_todo(id)
  -- Refresh UI if open
  if require("todo.ui").is_open() then
    require("todo.ui").refresh()
  end
end

M.stats = function()
  require("todo.stats").show()
end

return M
