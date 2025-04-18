local M = {}

-- Get the plugin configuration
local config = require("todo").config

-- Execute a query using vim-dadbod
local function execute_query(query, params)
  -- Check if vim-dadbod is available by looking for its commands
  if vim.fn.exists(':DB') == 0 then
    vim.notify("vim-dadbod is required but not installed or not loaded. Please ensure it's installed and loaded before todo.nvim.", vim.log.levels.ERROR)
    return nil
  end
  
  -- Prepare query with parameters if provided
  local final_query = query
  if params then
    for key, value in pairs(params) do
      -- Simple parameter replacement, can be improved for security
      if value == nil then
        value = "NULL"
      elseif type(value) == "string" then
        value = "'" .. value:gsub("'", "''") .. "'"
      end
      final_query = final_query:gsub(":" .. key, tostring(value))
    end
  end
  
  -- Create a temporary file for the query
  local temp_file = os.tmpname()
  local file = io.open(temp_file, "w")
  file:write(final_query)
  file:close()
  
  -- Execute query using vim-dadbod's :DB command
  local output_file = os.tmpname()
  local db_url = config.db.url
  
  -- Use :DB to execute the query and redirect output to a file
  vim.cmd(string.format('redir > %s', output_file))
  vim.cmd(string.format('silent DB %s < %s', db_url, temp_file))
  vim.cmd('redir END')
  
  -- Read the output
  local output_handle = io.open(output_file, "r")
  local result = ""
  if output_handle then
    result = output_handle:read("*a")
    output_handle:close()
  end
  
  -- Clean up
  os.remove(temp_file)
  os.remove(output_file)
  
  -- Parse result if needed
  if result and result ~= "" then
    -- Try to parse as JSON if applicable
    if result:match("^%s*{") or result:match("^%s*%[") then
      local ok, parsed = pcall(vim.fn.json_decode, result)
      if ok then
        return parsed
      end
    end
    
    -- Return the result lines as a table
    local lines = {}
    for line in result:gmatch("[^\r\n]+") do
      table.insert(lines, line)
    end
    
    if #lines > 0 then
      return lines
    end
  end
  
  return nil
end

-- Check if database connection works
function M.check_connection()
  local success, _ = pcall(execute_query, "SELECT 1")
  return success
end

-- Todo CRUD operations

-- Create a new todo
function M.create_todo(todo)
  local query = [[
    INSERT INTO todos (title, description, priority, due_date, tags, project)
    VALUES (:title, :description, :priority, :due_date, :tags, :project)
    RETURNING id
  ]]
  
  local result = execute_query(query, {
    title = todo.title or "",
    description = todo.description or "",
    priority = todo.priority or "M",
    due_date = todo.due_date or nil,
    tags = todo.tags or "{}",
    project = todo.project or ""
  })
  
  return result
end

-- Get all todos
function M.get_todos(filter)
  local query = [[
    SELECT id, title, description, priority, 
           due_date, completed, completed_at, 
           created_at, tags, project
    FROM todos
  ]]
  
  -- Add WHERE clauses based on filter
  if filter then
    local where_clauses = {}
    
    if filter.completed ~= nil then
      table.insert(where_clauses, "completed = " .. (filter.completed and "TRUE" or "FALSE"))
    end
    
    if filter.priority then
      table.insert(where_clauses, "priority = '" .. filter.priority .. "'")
    end
    
    if filter.project then
      table.insert(where_clauses, "project = '" .. filter.project .. "'")
    end
    
    if filter.tag then
      table.insert(where_clauses, "tags @> ARRAY['" .. filter.tag .. "']")
    end
    
    if filter.due_date then
      table.insert(where_clauses, "due_date <= '" .. filter.due_date .. "'")
    end
    
    if #where_clauses > 0 then
      query = query .. " WHERE " .. table.concat(where_clauses, " AND ")
    end
  end
  
  -- Add ORDER BY clause
  query = query .. " ORDER BY completed, priority ASC, due_date ASC"
  
  return execute_query(query)
end

-- Get a single todo by ID
function M.get_todo(id)
  local query = [[
    SELECT id, title, description, priority, 
           due_date, completed, completed_at, 
           created_at, tags, project
    FROM todos
    WHERE id = :id
  ]]
  
  local result = execute_query(query, { id = id })
  if result and #result > 0 then
    return result[1]
  end
  return nil
end

-- Update a todo
function M.update_todo(id, todo)
  local fields = {}
  local params = { id = id }
  
  -- Only update provided fields
  if todo.title then
    table.insert(fields, "title = :title")
    params.title = todo.title
  end
  
  if todo.description then
    table.insert(fields, "description = :description")
    params.description = todo.description
  end
  
  if todo.priority then
    table.insert(fields, "priority = :priority")
    params.priority = todo.priority
  end
  
  if todo.due_date then
    table.insert(fields, "due_date = :due_date")
    params.due_date = todo.due_date
  elseif todo.due_date == "" then
    -- Handle empty string to set NULL
    table.insert(fields, "due_date = NULL")
  end
  
  if todo.tags then
    table.insert(fields, "tags = :tags")
    params.tags = todo.tags
  end
  
  if todo.project then
    table.insert(fields, "project = :project")
    params.project = todo.project
  end
  
  -- If no fields to update, return
  if #fields == 0 then
    return false
  end
  
  local query = [[
    UPDATE todos
    SET ]] .. table.concat(fields, ", ") .. [[
    WHERE id = :id
  ]]
  
  execute_query(query, params)
  return true
end

-- Mark a todo as completed
function M.complete_todo(id)
  local query = [[
    UPDATE todos
    SET completed = TRUE, completed_at = NOW()
    WHERE id = :id
  ]]
  
  execute_query(query, { id = id })
  return true
end

-- Delete a todo
function M.delete_todo(id)
  local query = [[
    DELETE FROM todos
    WHERE id = :id
  ]]
  
  execute_query(query, { id = id })
  return true
end

-- Get statistics
function M.get_stats()
  local queries = {
    total = "SELECT COUNT(*) as count FROM todos",
    completed = "SELECT COUNT(*) as count FROM todos WHERE completed = TRUE",
    pending = "SELECT COUNT(*) as count FROM todos WHERE completed = FALSE",
    high_priority = "SELECT COUNT(*) as count FROM todos WHERE priority = 'H' AND completed = FALSE",
    overdue = "SELECT COUNT(*) as count FROM todos WHERE due_date < CURRENT_DATE AND completed = FALSE",
    completed_today = "SELECT COUNT(*) as count FROM todos WHERE DATE(completed_at) = CURRENT_DATE",
    by_project = "SELECT project, COUNT(*) as count FROM todos GROUP BY project ORDER BY count DESC",
    by_tags = "SELECT UNNEST(tags) as tag, COUNT(*) as count FROM todos GROUP BY tag ORDER BY count DESC",
  }
  
  local stats = {}
  
  for key, query in pairs(queries) do
    stats[key] = execute_query(query)
  end
  
  return stats
end

-- Check if database connection works
function M.check_connection()
  local success, _ = pcall(execute_query, "SELECT 1")
  return success
end

-- Todo CRUD operations

-- Create a new todo
function M.create_todo(todo)
  local query = [[
    INSERT INTO todos (title, description, priority, due_date, tags, project)
    VALUES (:title, :description, :priority, :due_date, :tags, :project)
    RETURNING id
  ]]
  
  local result = execute_query(query, {
    title = todo.title or "",
    description = todo.description or "",
    priority = todo.priority or "M",
    due_date = todo.due_date or "NULL",
    tags = todo.tags or "{}",
    project = todo.project or ""
  })
  
  return result
end

-- Get all todos
function M.get_todos(filter)
  local query = [[
    SELECT id, title, description, priority, 
           due_date, completed, completed_at, 
           created_at, tags, project
    FROM todos
  ]]
  
  -- Add WHERE clauses based on filter
  if filter then
    local where_clauses = {}
    
    if filter.completed ~= nil then
      table.insert(where_clauses, "completed = " .. (filter.completed and "TRUE" or "FALSE"))
    end
    
    if filter.priority then
      table.insert(where_clauses, "priority = '" .. filter.priority .. "'")
    end
    
    if filter.project then
      table.insert(where_clauses, "project = '" .. filter.project .. "'")
    end
    
    if filter.tag then
      table.insert(where_clauses, "tags @> ARRAY['" .. filter.tag .. "']")
    end
    
    if filter.due_date then
      table.insert(where_clauses, "due_date <= '" .. filter.due_date .. "'")
    end
    
    if #where_clauses > 0 then
      query = query .. " WHERE " .. table.concat(where_clauses, " AND ")
    end
  end
  
  -- Add ORDER BY clause
  query = query .. " ORDER BY completed, priority ASC, due_date ASC"
  
  return execute_query(query)
end

-- Get a single todo by ID
function M.get_todo(id)
  local query = [[
    SELECT id, title, description, priority, 
           due_date, completed, completed_at, 
           created_at, tags, project
    FROM todos
    WHERE id = :id
  ]]
  
  local result = execute_query(query, { id = id })
  if result and #result > 0 then
    return result[1]
  end
  return nil
end

-- Update a todo
function M.update_todo(id, todo)
  local fields = {}
  local params = { id = id }
  
  -- Only update provided fields
  if todo.title then
    table.insert(fields, "title = :title")
    params.title = todo.title
  end
  
  if todo.description then
    table.insert(fields, "description = :description")
    params.description = todo.description
  end
  
  if todo.priority then
    table.insert(fields, "priority = :priority")
    params.priority = todo.priority
  end
  
  if todo.due_date then
    table.insert(fields, "due_date = :due_date")
    params.due_date = todo.due_date
  elseif todo.due_date == "" then
    -- Handle empty string to set NULL
    table.insert(fields, "due_date = NULL")
  end
  
  if todo.tags then
    table.insert(fields, "tags = :tags")
    params.tags = todo.tags
  end
  
  if todo.project then
    table.insert(fields, "project = :project")
    params.project = todo.project
  end
  
  -- If no fields to update, return
  if #fields == 0 then
    return false
  end
  
  local query = [[
    UPDATE todos
    SET ]] .. table.concat(fields, ", ") .. [[
    WHERE id = :id
  ]]
  
  execute_query(query, params)
  return true
end

-- Mark a todo as completed
function M.complete_todo(id)
  local query = [[
    UPDATE todos
    SET completed = TRUE, completed_at = NOW()
    WHERE id = :id
  ]]
  
  execute_query(query, { id = id })
  return true
end

-- Delete a todo
function M.delete_todo(id)
  local query = [[
    DELETE FROM todos
    WHERE id = :id
  ]]
  
  execute_query(query, { id = id })
  return true
end

-- Get statistics
function M.get_stats()
  local queries = {
    total = "SELECT COUNT(*) as count FROM todos",
    completed = "SELECT COUNT(*) as count FROM todos WHERE completed = TRUE",
    pending = "SELECT COUNT(*) as count FROM todos WHERE completed = FALSE",
    high_priority = "SELECT COUNT(*) as count FROM todos WHERE priority = 'H' AND completed = FALSE",
    overdue = "SELECT COUNT(*) as count FROM todos WHERE due_date < CURRENT_DATE AND completed = FALSE",
    completed_today = "SELECT COUNT(*) as count FROM todos WHERE DATE(completed_at) = CURRENT_DATE",
    by_project = "SELECT project, COUNT(*) as count FROM todos GROUP BY project ORDER BY count DESC",
    by_tags = "SELECT UNNEST(tags) as tag, COUNT(*) as count FROM todos GROUP BY tag ORDER BY count DESC",
  }
  
  local stats = {}
  
  for key, query in pairs(queries) do
    stats[key] = execute_query(query)
  end
  
  return stats
end

return M
