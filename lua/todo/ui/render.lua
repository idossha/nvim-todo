local M = {}

local api = vim.api
local utils = require("todo.utils")
local config = require("todo").config

-- Helper function to get status line text
local function get_status_line(state)
  local status = {}
  
  -- Add filter status
  if state.current_filter then
    table.insert(status, "Filter: " .. state.current_filter)
  end
  
  -- Add sort status with direction
  if state.current_sort then
    local sort_direction = state.sort_ascending and "↑" or "↓"
    table.insert(status, "Sort: " .. state.current_sort .. " " .. sort_direction)
  end
  
  -- Add todo count
  local todo_count = #state.todos
  table.insert(status, todo_count .. " todos")
  
  return table.concat(status, " | ")
end

-- Helper function to format timestamp
local function format_timestamp(timestamp)
  if not timestamp then return "" end
  
  -- If it's already a number, use it directly
  if type(timestamp) == "number" then
    return os.date("%Y-%m-%d %H:%M", timestamp)
  end
  
  -- If it's a string, try to parse it
  if type(timestamp) == "string" then
    -- Try to convert to number
    local num = tonumber(timestamp)
    if num then
      return os.date("%Y-%m-%d %H:%M", num)
    end
    
    -- If it's already in date format, return it
    if timestamp:match("^%d%d%d%d%-%d%d%-%d%d") then
      return timestamp
    end
  end
  
  return ""
end

-- Format a todo item for display
local function format_todo(todo)
  local status = todo.completed and "✓" or " "
  local due = ""
  
  if todo.due_date and todo.due_date ~= "" then
    local is_overdue = not todo.completed and utils.is_overdue(todo.due_date)
    due = " [" .. todo.due_date .. "]"
  end
  
  -- Get creation date/time
  local created_at = ""
  if todo.created_at then
    local date = format_timestamp(todo.created_at)
    if date ~= "" then
      created_at = "created: " .. date
    end
  end
  
  -- Get completion date/time if completed
  local completed_at = ""
  if todo.completed and todo.completed_at then
    local date = format_timestamp(todo.completed_at)
    if date ~= "" then
      completed_at = " completed: " .. date
    end
  end
  
  -- Priority letter
  local priority = todo.priority or "M"
  
  local tags = ""
  if todo.tags and #todo.tags > 0 then
    tags = " #" .. table.concat(todo.tags, " #")
  end
  
  local project = ""
  if todo.project and todo.project ~= "" then
    project = " @" .. todo.project
  end
  
  -- Calculate the main content length
  local main_content = string.format(
    "[%s] [%s]  %s%s%s%s",
    status,
    priority,
    todo.title,
    due,
    project,
    tags
  )
  
  -- Calculate padding to align dates to the right
  local padding = string.rep(" ", math.max(0, 80 - #main_content - #created_at - #completed_at))
  
  return string.format(
    "%s%s%s%s",
    main_content,
    padding,
    created_at,
    completed_at
  ), todo.id
end

-- Sort todos based on current sort settings
function M.sort_todos(state)
  if not state.current_sort then
    return
  end
  
  table.sort(state.todos, function(a, b)
    local a_val, b_val
    
    if state.current_sort == "Date" then
      a_val = a.due_date or a.created_at
      b_val = b.due_date or b.created_at
    elseif state.current_sort == "Priority" then
      a_val = a.priority
      b_val = b.priority
    elseif state.current_sort == "Project" then
      a_val = a.project or ""
      b_val = b.project or ""
    end
    
    if state.sort_ascending then
      return a_val < b_val
    else
      return a_val > b_val
    end
  end)
end

-- Render todos in the buffer
function M.render_todos(state)
  if not state.buffer or not api.nvim_buf_is_valid(state.buffer) then
    return
  end
  
  api.nvim_buf_set_option(state.buffer, "modifiable", true)
  
  -- Get status line
  local status_line = get_status_line(state)
  
  -- Prepare lines
  local lines = { status_line, "" }
  local line_to_id = {}
  
  -- Add todos
  for i, todo in ipairs(state.todos) do
    local line, id = format_todo(todo)
    table.insert(lines, line)
    line_to_id[i + 2] = id
  end
  
  -- Set lines and variables
  api.nvim_buf_set_lines(state.buffer, 0, -1, false, lines)
  api.nvim_buf_set_var(state.buffer, "line_to_id", line_to_id)
  
  -- Add highlights
  local ns_id = api.nvim_create_namespace("TodoHighlights")
  api.nvim_buf_clear_namespace(state.buffer, ns_id, 0, -1)
  
  -- Highlight status line
  api.nvim_buf_add_highlight(state.buffer, ns_id, "TodoStatusLine", 0, 0, -1)
  
  -- Highlight completed todos
  for i, todo in ipairs(state.todos) do
    local line = i + 2
    if todo.completed then
      api.nvim_buf_add_highlight(state.buffer, ns_id, "TodoCompleted", line - 1, 0, -1)
    end
  end
  
  api.nvim_buf_set_option(state.buffer, "modifiable", false)
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
