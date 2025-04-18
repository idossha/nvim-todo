local M = {}

local api = vim.api
local utils = require("todo.utils")
local config = require("todo").config

-- Format a todo item for display
local function format_todo(todo)
  local status = todo.completed and "✓" or " "
  local due = ""
  
  if todo.due_date and todo.due_date ~= "" then
    local is_overdue = not todo.completed and utils.is_overdue(todo.due_date)
    due = " [" .. todo.due_date .. "]"
  end
  
  local priority_marker = ""
  if todo.priority == "H" then
    priority_marker = "!"
  elseif todo.priority == "M" then
    priority_marker = "·"
  end
  
  local tags = ""
  if todo.tags and #todo.tags > 0 then
    tags = " #" .. table.concat(todo.tags, " #")
  end
  
  local project = ""
  if todo.project and todo.project ~= "" then
    project = " @" .. todo.project
  end
  
  return string.format(
    "[%s] %s %s%s%s%s", 
    status, 
    priority_marker, 
    todo.title,
    due,
    project,
    tags
  ), todo.id
end

-- Sort todos based on current sort settings
function M.sort_todos(state)
  table.sort(state.todos, function(a, b)
    local field = state.sort.field
    local asc = state.sort.ascending
    
    if field == "priority" then
      local priority_value = {H = 1, M = 2, L = 3}
      if asc then
        return priority_value[a.priority] < priority_value[b.priority]
      else
        return priority_value[a.priority] > priority_value[b.priority]
      end
    elseif field == "due_date" then
      if not a.due_date then return not asc end
      if not b.due_date then return asc end
      if asc then
        return a.due_date < b.due_date
      else
        return a.due_date > b.due_date
      end
    elseif field == "created_at" then
      if asc then
        return a.created_at < b.created_at
      else
        return a.created_at > b.created_at
      end
    else -- Default to title
      if asc then
        return a.title < b.title
      else
        return a.title > b.title
      end
    end
  end)
end

-- Render todos in the buffer
function M.render_todos(state)
  if not state.buffer or not api.nvim_buf_is_valid(state.buffer) then
    return
  end
  
  -- Clear buffer
  api.nvim_buf_set_option(state.buffer, "modifiable", true)
  api.nvim_buf_set_lines(state.buffer, 0, -1, false, {})
  
  -- Add header
  local filter_active = state.filter.completed ~= nil or 
                        state.filter.priority ~= nil or 
                        state.filter.project ~= nil or
                        state.filter.tag ~= nil or
                        state.filter.due_date ~= nil
  
  local header = ""
  if filter_active then
    header = "Filter active | "
  end
  
  header = header .. string.format(
    "Sort: %s %s | %d todos", 
    state.sort.field, 
    state.sort.ascending and "↑" or "↓",
    #state.todos
  )
  
  api.nvim_buf_set_lines(state.buffer, 0, 0, false, {header, ""})
  
  -- Format and add todos
  local lines = {}
  local line_to_id = {}
  
  for i, todo in ipairs(state.todos) do
    local line, id = format_todo(todo)
    table.insert(lines, line)
    line_to_id[i+2] = id  -- +2 for header lines
  end
  
  -- Set formatted lines
  api.nvim_buf_set_lines(state.buffer, 2, 2, false, lines)
  api.nvim_buf_set_option(state.buffer, "modifiable", false)
  
  -- Store line to ID mapping in buffer variable
  api.nvim_buf_set_var(state.buffer, "line_to_id", line_to_id)
  
  -- Apply syntax highlighting
  M.apply_highlighting(state)
end

-- Apply syntax highlighting to todos
function M.apply_highlighting(state)
  local ns_id = api.nvim_create_namespace("TodoHighlight")
  api.nvim_buf_clear_namespace(state.buffer, ns_id, 0, -1)
  
  for i, todo in ipairs(state.todos) do
    local line_num = i + 2  -- +2 for header lines
    local line = api.nvim_buf_get_lines(state.buffer, line_num-1, line_num, false)[1]
    
    -- Priority highlighting
    if todo.priority == "H" then
      api.nvim_buf_add_highlight(state.buffer, ns_id, config.ui.highlight.priority_high, line_num-1, 4, 5)
    elseif todo.priority == "M" then
      api.nvim_buf_add_highlight(state.buffer, ns_id, config.ui.highlight.priority_medium, line_num-1, 4, 5)
    elseif todo.priority == "L" then
      api.nvim_buf_add_highlight(state.buffer, ns_id, config.ui.highlight.priority_low, line_num-1, 4, 5)
    end
    
    -- Completed task
    if todo.completed then
      api.nvim_buf_add_highlight(state.buffer, ns_id, config.ui.highlight.completed, line_num-1, 0, -1)
    end
    
    -- Due date
    if todo.due_date and todo.due_date ~= "" then
      local due_start = line:find("%[%d%d%d%d%-%d%d%-%d%d%]")
      if due_start then
        local due_end = due_start + 11  -- [YYYY-MM-DD] is 12 chars
        local highlight = config.ui.highlight.due_date
        
        -- Check if overdue
        if not todo.completed and utils.is_overdue(todo.due_date) then
          highlight = config.ui.highlight.overdue
        end
        
        api.nvim_buf_add_highlight(state.buffer, ns_id, highlight, line_num-1, due_start-1, due_end)
      end
    end
    
    -- Tags
    local tag_start = line:find("#%w+")
    while tag_start do
      local tag_end = line:find("%s", tag_start) or #line + 1
      api.nvim_buf_add_highlight(state.buffer, ns_id, config.ui.highlight.tags, line_num-1, tag_start-1, tag_end-1)
      tag_start = line:find("#%w+", tag_end)
    end
  end
end

return M
