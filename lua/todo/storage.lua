local M = {}

local config = require("todo").config
local utils = require("todo.utils")

-- Internal state
M.todos = {}
M.next_id = 1

-- Initialize storage
function M.init()
  -- Try to load existing data file
  local file_path = config.storage.path
  local file = io.open(file_path, "r")
  
  if file then
    local content = file:read("*all")
    file:close()
    
    if content and content ~= "" then
      -- Try to parse JSON
      local success, data = pcall(vim.fn.json_decode, content)
      if success and data then
        M.todos = data.todos or {}
        M.next_id = data.next_id or 1
      else
        vim.notify("Failed to parse todos data file. Starting with empty todo list.", vim.log.levels.WARN)
        M.todos = {}
        M.next_id = 1
      end
    end
  else
    -- Create a new data file with empty structure
    M.save()
  end
end

-- Save current state to file
function M.save()
  local file_path = config.storage.path
  local file = io.open(file_path, "w")
  
  if file then
    local data = {
      todos = M.todos,
      next_id = M.next_id
    }
    
    local json_str = vim.fn.json_encode(data)
    file:write(json_str)
    file:close()
  else
    vim.notify("Failed to save todos data file: " .. file_path, vim.log.levels.ERROR)
  end
end

-- Get all todos
function M.get_all_todos()
  return M.todos
end

-- Create a new todo
function M.create_todo(todo)
  -- Assign an ID
  local id = M.next_id
  M.next_id = M.next_id + 1
  
  -- Set defaults for missing fields
  local new_todo = {
    id = id,
    title = todo.title or "",
    description = todo.description or "",
    priority = todo.priority or "M",
    due_date = todo.due_date or nil,
    tags = todo.tags or {},
    project = todo.project or "",
    completed = false,
    completed_at = nil,
    created_at = os.time()
  }
  
  -- Add to storage
  table.insert(M.todos, new_todo)
  
  -- Save changes
  M.save()
  
  return id
end

-- Get a single todo by ID
function M.get_todo(id)
  for _, todo in ipairs(M.todos) do
    if todo.id == id then
      return todo
    end
  end
  
  return nil
end

-- Update a todo
function M.update_todo(id, updates)
  local todo = M.get_todo(id)
  
  if not todo then
    return false
  end
  
  -- Update fields
  for k, v in pairs(updates) do
    if k ~= "id" and k ~= "created_at" then
      todo[k] = v
    end
  end
  
  -- Save changes
  M.save()
  
  return true
end

-- Mark a todo as completed
function M.complete_todo(id)
  local todo = M.get_todo(id)
  
  if not todo then
    return false
  end
  
  todo.completed = true
  todo.completed_at = os.time()
  
  -- Save changes
  M.save()
  
  return true
end

-- Delete a todo
function M.delete_todo(id)
  for i, todo in ipairs(M.todos) do
    if todo.id == id then
      table.remove(M.todos, i)
      
      -- Save changes
      M.save()
      
      return true
    end
  end
  
  return false
end

-- Get statistics
function M.get_stats()
  local stats = {
    total = #M.todos,
    completed = 0,
    pending = 0,
    high_priority = 0,
    overdue = 0,
    completed_today = 0,
    by_project = {},
    by_tags = {}
  }
  
  local today = os.date("%Y-%m-%d")
  
  for _, todo in ipairs(M.todos) do
    -- Count completed vs pending
    if todo.completed then
      stats.completed = stats.completed + 1
      
      -- Check if completed today
      if todo.completed_at and todo.completed_at:sub(1, 10) == today then
        stats.completed_today = stats.completed_today + 1
      end
    else
      stats.pending = stats.pending + 1
      
      -- Count high priority
      if todo.priority == "H" then
        stats.high_priority = stats.high_priority + 1
      end
      
      -- Count overdue
      if todo.due_date and utils.is_overdue(todo.due_date) then
        stats.overdue = stats.overdue + 1
      end
    end
    
    -- Count by project
    local project = todo.project or "(no project)"
    stats.by_project[project] = (stats.by_project[project] or 0) + 1
    
    -- Count by tags
    if todo.tags then
      for _, tag in ipairs(todo.tags) do
        stats.by_tags[tag] = (stats.by_tags[tag] or 0) + 1
      end
    end
  end
  
  return stats
end

return M
