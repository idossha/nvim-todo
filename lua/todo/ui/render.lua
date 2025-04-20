local M = {}

local api = vim.api
local utils = require("todo.utils")
local config = require("todo").config

-- Helper function to get status line text
local function get_status_line(state, filtered_count)
  local status = {}
  
  -- Add filter status
  if state.current_filter then
    table.insert(status, "Filter: " .. state.current_filter)
  else
    table.insert(status, "Filter: none")
  end
  
  -- Add sort status with direction
  if state.current_sort then
    local sort_direction = state.sort_ascending and "↑" or "↓"
    table.insert(status, "Sort: " .. state.current_sort .. " " .. sort_direction)
  else
    table.insert(status, "Sort: none")
  end
  
  -- Add todo count (filtered)
  table.insert(status, filtered_count .. " todos")
  
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
-- Now sorts the provided list in place
local function sort_todos(todos_list, state)
  if not state.current_sort then
    return
  end
  
  table.sort(todos_list, function(a, b)
    local a_val, b_val
    
    if state.current_sort == "Date" then
      a_val = a.due_date or a.created_at or 0 -- Handle nil dates for sorting
      b_val = b.due_date or b.created_at or 0
      -- Convert timestamps to numbers if they are strings
      a_val = type(a_val) == "string" and tonumber(a_val) or a_val
      b_val = type(b_val) == "string" and tonumber(b_val) or b_val
    elseif state.current_sort == "Priority" then
      -- Define priority order
      local priority_order = { H = 1, M = 2, L = 3 }
      a_val = priority_order[a.priority] or 2
      b_val = priority_order[b.priority] or 2
    elseif state.current_sort == "Project" then
      a_val = a.project or "zzzz"
      b_val = b.project or "zzzz"
    else
      return false -- Should not happen
    end
    
    -- Handle potential nil values after conversion/lookup
    a_val = a_val or (state.sort_ascending and math.huge or -math.huge)
    b_val = b_val or (state.sort_ascending and math.huge or -math.huge)
    
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
  
  -- Start with all todos from the current state
  local current_todos = state.todos
  
  -- Sort the current list if needed
  sort_todos(current_todos, state)
  
  -- Filter todos based on current filter
  local filtered_todos = {}
  for _, todo in ipairs(current_todos) do
    local include = true
    
    if state.current_filter then
      if state.current_filter == "completed" then
        include = todo.completed
      elseif state.current_filter == "open" then
        include = not todo.completed
      elseif state.current_filter:match("^priority:") then
        local priority_filter = state.current_filter:match("^priority:(.+)$")
        -- Compare with actual priority value (H, M, L)
        if priority_filter == "High" then
            include = todo.priority == "H"
        elseif priority_filter == "Medium" then
            include = todo.priority == "M"
        elseif priority_filter == "Low" then
            include = todo.priority == "L"
        else
            include = false -- Invalid priority filter
        end
      elseif state.current_filter == "tags" then
        -- TODO: Implement actual tag filtering based on user input
        include = todo.tags and #todo.tags > 0 -- Placeholder: checks if tags exist
      elseif state.current_filter == "project" then
        -- TODO: Implement actual project filtering based on user input
        include = todo.project and todo.project ~= "" -- Placeholder: checks if project exists
      end
    end
    
    if include then
      table.insert(filtered_todos, todo)
    end
  end
  
  -- Get status line based on filtered count
  local status_line = get_status_line(state, #filtered_todos)
  
  -- Prepare lines
  local lines = { status_line, "" }
  local line_to_id = {}
  
  -- Add filtered todos
  for i, todo in ipairs(filtered_todos) do
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
  
  -- Highlight completed todos in the filtered list
  for i, todo in ipairs(filtered_todos) do
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
