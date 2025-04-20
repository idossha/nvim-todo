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

-- Get statistics about todos
function M.get_stats()
  local todos = M.get_all_todos()
  local stats = {
    total = #todos,
    completed = 0,
    open = 0,
    high_priority = 0,
    medium_priority = 0,
    low_priority = 0,
    overdue = 0,
    completed_today = 0,
    completed_this_week = 0,
    completed_this_month = 0,
  }
  
  local now = os.time()
  local today = os.date("*t", now)
  today.hour = 0
  today.min = 0
  today.sec = 0
  local today_start = os.time(today)
  
  for _, todo in ipairs(todos) do
    if todo.completed then
      stats.completed = stats.completed + 1
      
      -- Check completion time
      if todo.completed_at then
        local completed_time = type(todo.completed_at) == "number" and todo.completed_at or tonumber(todo.completed_at)
        if completed_time then
          local completed_date = os.date("*t", completed_time)
          
          -- Completed today
          if completed_time >= today_start then
            stats.completed_today = stats.completed_today + 1
          end
          
          -- Completed this week
          local week_start = today_start - (today.wday - 1) * 24 * 60 * 60
          if completed_time >= week_start then
            stats.completed_this_week = stats.completed_this_week + 1
          end
          
          -- Completed this month
          local month_start = os.time({year = today.year, month = today.month, day = 1})
          if completed_time >= month_start then
            stats.completed_this_month = stats.completed_this_month + 1
          end
        end
      end
    else
      stats.open = stats.open + 1
      
      -- Check if overdue
      if todo.due_date then
        local due_time = type(todo.due_date) == "number" and todo.due_date or tonumber(todo.due_date)
        if due_time and due_time < now then
          stats.overdue = stats.overdue + 1
        end
      end
    end
    
    -- Count priorities
    if todo.priority == "H" then
      stats.high_priority = stats.high_priority + 1
    elseif todo.priority == "M" then
      stats.medium_priority = stats.medium_priority + 1
    elseif todo.priority == "L" then
      stats.low_priority = stats.low_priority + 1
    end
  end
  
  return stats
end

return M
