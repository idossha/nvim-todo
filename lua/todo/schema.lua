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
  -- Get the plugin configuration
  local vim_dadbod_loaded, _ = pcall(require, "vim.dadbod")
  
  if not vim_dadbod_loaded then
    vim.notify("vim-dadbod is required but not installed", vim.log.levels.ERROR)
    return false
  end
  
  -- Execute the schema creation SQL
  local success, err = pcall(vim.fn['db_execute'], config.db.url, schema_sql)
  
  if not success then
    vim.notify("Failed to initialize todo.nvim schema: " .. (err or "Unknown error"), vim.log.levels.ERROR)
    return false
  end
  
  return true
end

return M
