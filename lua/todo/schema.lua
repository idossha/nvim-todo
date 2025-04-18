local M = {}

-- Get db module
local db = require("todo.db")
local config = require("todo").config

-- SQL to create the todos table
local schema_sql = [[
CREATE TABLE IF NOT EXISTS todos (
  id SERIAL PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  priority CHAR(1) NOT NULL CHECK (priority IN ('H', 'M', 'L')) DEFAULT 'M',
  due_date DATE,
  completed BOOLEAN NOT NULL DEFAULT FALSE,
  completed_at TIMESTAMP,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  tags TEXT[] DEFAULT '{}',
  project TEXT DEFAULT ''
);

-- Create indexes for common queries
CREATE INDEX IF NOT EXISTS idx_todos_completed ON todos(completed);
CREATE INDEX IF NOT EXISTS idx_todos_priority ON todos(priority);
CREATE INDEX IF NOT EXISTS idx_todos_due_date ON todos(due_date);
CREATE INDEX IF NOT EXISTS idx_todos_project ON todos(project);
CREATE INDEX IF NOT EXISTS idx_todos_tags ON todos USING GIN(tags);
]]

-- Initialize the database schema
function M.init()
  -- Check for vim-dadbod in multiple ways to ensure it's properly detected
  local vim_dadbod_exists = false
  
  -- First check if the plugin is loaded using vim's runtimepath
  if vim.fn.finddir('vim-dadbod', vim.o.runtimepath) ~= "" then
    vim_dadbod_exists = true
  end
  
  -- Also check if the db#execute function exists
  if vim.fn.exists('*db#execute') > 0 then
    vim_dadbod_exists = true
  end
  
  if not vim_dadbod_exists then
    vim.notify("vim-dadbod is required but not installed or not properly loaded. Please ensure it's installed and loaded before todo.nvim.", vim.log.levels.ERROR)
    return false
  end
  
  -- Execute the schema creation SQL
  local success, result
  
  -- Try db#execute first (Vim script interface)
  success, result = pcall(function()
    return vim.fn['db#execute'](config.db.url, schema_sql)
  end)
  
  -- If that fails, try db_execute (older interface)
  if not success then
    success, result = pcall(function()
      return vim.fn['db_execute'](config.db.url, schema_sql)
    end)
  end
  
  -- If both fail, try one more approach with vim.cmd
  if not success then
    success, result = pcall(function()
      return vim.cmd('echo db#execute("' .. vim.fn.escape(config.db.url, '"') .. '", "' .. vim.fn.escape(schema_sql, '"\\') .. '")')
    end)
  end
  
  if not success then
    vim.notify("Failed to initialize todo.nvim schema: " .. tostring(result), vim.log.levels.ERROR)
    return false
  end
  
  vim.notify("Todo.nvim schema initialized successfully!", vim.log.levels.INFO)
  return true
end

return M
