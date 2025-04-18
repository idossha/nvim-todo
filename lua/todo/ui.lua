local M = {}

local api = vim.api
local storage = require("todo.storage")
local utils = require("todo.utils")
local config = require("todo").config

-- UI state
M.state = {
  buffer = nil,
  window = nil,
  todos = {},
  filter = {
    completed = false,
    priority = nil,
    project = nil,
    tag = nil,
    due_date = nil,
  },
  sort = {
    field = "priority",
    ascending = true,
  },
}

-- Check if the UI is open
function M.is_open()
  return M.state.buffer ~= nil and api.nvim_buf_is_valid(M.state.buffer) and
         M.state.window ~= nil and api.nvim_win_is_valid(M.state.window)
end

-- Create the floating window for todos
local function create_window()
  -- Create buffer if it doesn't exist
  if not M.state.buffer or not api.nvim_buf_is_valid(M.state.buffer) then
    M.state.buffer = api.nvim_create_buf(false, true)
    api.nvim_buf_set_option(M.state.buffer, "bufhidden", "wipe")
    api.nvim_buf_set_option(M.state.buffer, "filetype", "todo")
  end
  
  -- Calculate window size and position
  local width = config.ui.width
  local height = config.ui.height
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  
  -- Window options
  local opts = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = config.ui.border,
    title = " Todo List ",
    title_pos = "center",
  }
  
  -- Create window if it doesn't exist or is not valid
  if not M.state.window or not api.nvim_win_is_valid(M.state.window) then
    M.state.window = api.nvim_open_win(M.state.buffer, true, opts)
    api.nvim_win_set_option(M.state.window, "winhighlight", "Normal:Normal,FloatBorder:FloatBorder")
    api.nvim_win_set_option(M.state.window, "cursorline", true)
  end
  
  -- Set buffer options
  api.nvim_buf_set_option(M.state.buffer, "modifiable", false)
  api.nvim_buf_set_option(M.state.buffer, "buftype", "nofile")
  
  -- Set up keybindings
  local mappings = {
    [config.mappings.add] = M.add_todo,
    [config.mappings.delete] = M.delete_todo_under_cursor,
    [config.mappings.complete] = M.complete_todo_under_cursor,
    [config.mappings.edit] = M.edit_todo_under_cursor,
    [config.mappings.tags] = M.edit_tags,
    [config.mappings.priority] = M.set_priority,
    [config.mappings.due_date] = M.set_due_date,
    [config.mappings.sort] = M.show_sort_menu,
    [config.mappings.filter] = M.show_filter_menu,
    [config.mappings.close] = M.close,
    [config.mappings.help] = M.show_help,
  }
  
  for key, func in pairs(mappings) do
    api.nvim_buf_set_keymap(M.state.buffer, "n", key, "", {
      noremap = true,
      silent = true,
      callback = func,
    })
  end
end

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

-- Render todos in the buffer
local function render_todos()
  if not M.is_open() then
    return
  end
  
  -- Clear buffer
  api.nvim_buf_set_option(M.state.buffer, "modifiable", true)
  api.nvim_buf_set_lines(M.state.buffer, 0, -1, false, {})
  
  -- Add header
  local filter_active = M.state.filter.completed ~= nil or 
                        M.state.filter.priority ~= nil or 
                        M.state.filter.project ~= nil or
                        M.state.filter.tag ~= nil or
                        M.state.filter.due_date ~= nil
  
  local header = ""
  if filter_active then
    header = "Filter active | "
  end
  
  header = header .. string.format(
    "Sort: %s %s | %d todos", 
    M.state.sort.field, 
    M.state.sort.ascending and "↑" or "↓",
    #M.state.todos
  )
  
  api.nvim_buf_set_lines(M.state.buffer, 0, 0, false, {header, ""})
  
  -- Format and add todos
  local lines = {}
  local line_to_id = {}
  
  for i, todo in ipairs(M.state.todos) do
    local line, id = format_todo(todo)
    table.insert(lines, line)
    line_to_id[i+2] = id  -- +2 for header lines
  end
  
  -- Set formatted lines
  api.nvim_buf_set_lines(M.state.buffer, 2, 2, false, lines)
  api.nvim_buf_set_option(M.state.buffer, "modifiable", false)
  
  -- Store line to ID mapping in buffer variable
  api.nvim_buf_set_var(M.state.buffer, "line_to_id", line_to_id)
  
  -- Apply syntax highlighting
  local ns_id = api.nvim_create_namespace("TodoHighlight")
  api.nvim_buf_clear_namespace(M.state.buffer, ns_id, 0, -1)
  
  for i, todo in ipairs(M.state.todos) do
    local line_num = i + 2  -- +2 for header lines
    local line = api.nvim_buf_get_lines(M.state.buffer, line_num-1, line_num, false)[1]
    
    -- Priority highlighting
    if todo.priority == "H" then
      api.nvim_buf_add_highlight(M.state.buffer, ns_id, config.ui.highlight.priority_high, line_num-1, 4, 5)
    elseif todo.priority == "M" then
      api.nvim_buf_add_highlight(M.state.buffer, ns_id, config.ui.highlight.priority_medium, line_num-1, 4, 5)
    elseif todo.priority == "L" then
      api.nvim_buf_add_highlight(M.state.buffer, ns_id, config.ui.highlight.priority_low, line_num-1, 4, 5)
    end
    
    -- Completed task
    if todo.completed then
      api.nvim_buf_add_highlight(M.state.buffer, ns_id, config.ui.highlight.completed, line_num-1, 0, -1)
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
        
        api.nvim_buf_add_highlight(M.state.buffer, ns_id, highlight, line_num-1, due_start-1, due_end)
      end
    end
    
    -- Tags
    local tag_start = line:find("#%w+")
    while tag_start do
      local tag_end = line:find("%s", tag_start) or #line + 1
      api.nvim_buf_add_highlight(M.state.buffer, ns_id, config.ui.highlight.tags, line_num-1, tag_start-1, tag_end-1)
      tag_start = line:find("#%w+", tag_end)
    end
  end
end

-- Load todos from storage
local function load_todos()
  local todos = storage.get_todos(M.state.filter)
  M.state.todos = todos or {}
  
  -- Apply current sort
  table.sort(M.state.todos, function(a, b)
    local field = M.state.sort.field
    local asc = M.state.sort.ascending
    
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
  
  render_todos()
end

-- Get todo ID under cursor
local function get_todo_id_at_cursor()
  if not M.is_open() then
    return nil
  end
  
  local line = api.nvim_win_get_cursor(M.state.window)[1]
  local line_to_id = api.nvim_buf_get_var(M.state.buffer, "line_to_id")
  
  return line_to_id[line]
end

-- Open the todo window
function M.open()
  create_window()
  load_todos()
end

-- Close the todo window
function M.close()
  if M.is_open() then
    api.nvim_win_close(M.state.window, true)
    M.state.window = nil
    M.state.buffer = nil
  end
end

-- Refresh the todo list
function M.refresh()
  load_todos()
end

-- Add a new todo
function M.add_todo(opts)
  opts = opts or {}
  
  -- Create input fields
  local title = vim.fn.input("Title [" .. todo.title .. "]: ")
  if title == "" then
    title = todo.title
  end
  
  local description = vim.fn.input("Description [" .. (todo.description or "") .. "]: ")
  if description == "" and todo.description then
    description = todo.description
  end
  
  local priority = vim.fn.input("Priority (H/M/L) [" .. todo.priority .. "]: ")
  if priority == "" then
    priority = todo.priority
  else
    priority = string.upper(string.sub(priority, 1, 1))
    if not (priority == "H" or priority == "M" or priority == "L") then
      priority = todo.priority
    end
  end
  
  local due_date = vim.fn.input("Due date (YYYY-MM-DD) [" .. (todo.due_date or "") .. "]: ")
  if due_date == "" and todo.due_date then
    due_date = todo.due_date
  end
  
  local project = vim.fn.input("Project [" .. (todo.project or "") .. "]: ")
  if project == "" and todo.project then
    project = todo.project
  end
  
  -- Update todo
  local updated_todo = {
    title = title,
    description = description,
    priority = priority,
    due_date = due_date ~= "" and due_date or nil,
    project = project,
  }
  
  storage.update_todo(id, updated_todo)
  M.refresh()
end

-- Edit tags for todo under cursor
function M.edit_tags()
  local id = get_todo_id_at_cursor()
  if not id then
    return
  end
  
  local todo = storage.get_todo(id)
  if not todo then
    vim.notify("Todo not found", vim.log.levels.ERROR)
    return
  end
  
  local tags_str = table.concat(todo.tags or {}, ", ")
  local tags_input = vim.fn.input("Tags (comma separated) [" .. tags_str .. "]: ")
  
  local tags
  if tags_input ~= "" then
    tags = vim.split(tags_input, ",")
    for i, tag in ipairs(tags) do
      tags[i] = vim.trim(tag)
    end
  else
    tags = todo.tags or {}
  end
  
  storage.update_todo(id, { tags = tags })
  M.refresh()
end

-- Set priority for todo under cursor
function M.set_priority()
  local id = get_todo_id_at_cursor()
  if not id then
    return
  end
  
  local priority = vim.fn.input("Priority (H/M/L): ")
  if priority == "" then
    return
  end
  
  priority = string.upper(string.sub(priority, 1, 1))
  if not (priority == "H" or priority == "M" or priority == "L") then
    vim.notify("Invalid priority. Use H, M, or L", vim.log.levels.ERROR)
    return
  end
  
  storage.update_todo(id, { priority = priority })
  M.refresh()
end

-- Set due date for todo under cursor
function M.set_due_date()
  local id = get_todo_id_at_cursor()
  if not id then
    return
  end
  
  local due_date = vim.fn.input("Due date (YYYY-MM-DD, empty for none): ")
  if due_date ~= "" and not due_date:match("^%d%d%d%d%-%d%d%-%d%d$") then
    vim.notify("Invalid date format. Use YYYY-MM-DD", vim.log.levels.ERROR)
    return
  end
  
  storage.update_todo(id, { due_date = due_date })
  M.refresh()
end

-- Show sort menu
function M.show_sort_menu()
  local sort_options = {
    { key = "p", name = "Priority", field = "priority" },
    { key = "d", name = "Due Date", field = "due_date" },
    { key = "c", name = "Creation Date", field = "created_at" },
    { key = "t", name = "Title", field = "title" },
  }
  
  -- Display options
  api.nvim_buf_set_option(M.state.buffer, "modifiable", true)
  api.nvim_buf_set_lines(M.state.buffer, 0, -1, false, {
    "--- Sort by ---",
    "",
  })
  
  local lines = {}
  for _, option in ipairs(sort_options) do
    local selected = M.state.sort.field == option.field
    local direction = M.state.sort.ascending and "↑" or "↓"
    local line = string.format("%s: %s %s", option.key, option.name, selected and direction or "")
    table.insert(lines, line)
  end
  
  table.insert(lines, "")
  table.insert(lines, "r: Reverse order")
  table.insert(lines, "")
  table.insert(lines, "Press any key to sort, Esc to cancel")
  
  api.nvim_buf_set_lines(M.state.buffer, 2, 2, false, lines)
  api.nvim_buf_set_option(M.state.buffer, "modifiable", false)
  
  -- Wait for keypress
  local key = vim.fn.getchar()
  
  -- Convert to string
  if type(key) == "number" then
    key = vim.fn.nr2char(key)
  end
  
  -- Handle key
  if key == "\27" then -- Escape
    -- Cancel, just refresh
    M.refresh()
    return
  elseif key == "r" then
    -- Reverse current sort
    M.state.sort.ascending = not M.state.sort.ascending
  else
    -- Look for sort option
    for _, option in ipairs(sort_options) do
      if key == option.key then
        if M.state.sort.field == option.field then
          -- Toggle direction if same field
          M.state.sort.ascending = not M.state.sort.ascending
        else
          -- Set new field with default direction
          M.state.sort.field = option.field
          M.state.sort.ascending = true
        end
        break
      end
    end
  end
  
  -- Refresh with new sort
  M.refresh()
end

-- Show filter menu
function M.show_filter_menu()
  local filter_options = {
    { key = "a", name = "All", filter = { completed = nil } },
    { key = "p", name = "Pending", filter = { completed = false } },
    { key = "c", name = "Completed", filter = { completed = true } },
    { key = "h", name = "High Priority", filter = { priority = "H", completed = false } },
    { key = "m", name = "Medium Priority", filter = { priority = "M", completed = false } },
    { key = "l", name = "Low Priority", filter = { priority = "L", completed = false } },
    { key = "d", name = "Due Today", filter = { due_date = os.date("%Y-%m-%d"), completed = false } },
    { key = "o", name = "Overdue", filter = { due_date = "<" .. os.date("%Y-%m-%d"), completed = false } },
    { key = "t", name = "By Tag", filter = "tag_prompt" },
    { key = "r", name = "By Project", filter = "project_prompt" },
    { key = "z", name = "Clear Filters", filter = {} },
  }
  
  -- Display options
  api.nvim_buf_set_option(M.state.buffer, "modifiable", true)
  api.nvim_buf_set_lines(M.state.buffer, 0, -1, false, {
    "--- Filter ---",
    ""
  })
  
  local lines = {}
  for _, option in ipairs(filter_options) do
    local line = string.format("%s: %s", option.key, option.name)
    table.insert(lines, line)
  end
  
  table.insert(lines, "")
  table.insert(lines, "Press a key to select filter, Esc to cancel")
  
  api.nvim_buf_set_lines(M.state.buffer, 2, 2, false, lines)
  api.nvim_buf_set_option(M.state.buffer, "modifiable", false)
  
  -- Wait for keypress
  local key = vim.fn.getchar()
  
  -- Convert to string
  if type(key) == "number" then
    key = vim.fn.nr2char(key)
  end
  
  -- Handle key
  if key == "\27" then -- Escape
    -- Cancel, just refresh
    M.refresh()
    return
  else
    -- Look for filter option
    for _, option in ipairs(filter_options) do
      if key == option.key then
        if option.filter == "tag_prompt" then
          -- Prompt for tag
          local tag = vim.fn.input("Filter by tag: ")
          if tag ~= "" then
            M.state.filter = { tag = tag, completed = false }
          end
        elseif option.filter == "project_prompt" then
          -- Prompt for project
          local project = vim.fn.input("Filter by project: ")
          if project ~= "" then
            M.state.filter = { project = project, completed = false }
          end
        else
          -- Apply filter
          M.state.filter = option.filter
        end
        break
      end
    end
  end
  
  -- Refresh with new filter
  M.refresh()
end

-- Show help
function M.show_help()
  local mappings = config.mappings
  
  -- Display help
  api.nvim_buf_set_option(M.state.buffer, "modifiable", true)
  api.nvim_buf_set_lines(M.state.buffer, 0, -1, false, {
    "--- Todo.nvim Help ---",
    "",
    string.format("%s: Add new todo", mappings.add),
    string.format("%s: Delete todo under cursor", mappings.delete),
    string.format("%s: Complete todo under cursor", mappings.complete),
    string.format("%s: Edit todo under cursor", mappings.edit),
    string.format("%s: Edit tags", mappings.tags),
    string.format("%s: Set priority", mappings.priority),
    string.format("%s: Set due date", mappings.due_date),
    string.format("%s: Sort todos", mappings.sort),
    string.format("%s: Filter todos", mappings.filter),
    string.format("%s: Close window", mappings.close),
    string.format("%s: Show this help", mappings.help),
    "",
    "Press any key to continue"
  })
  api.nvim_buf_set_option(M.state.buffer, "modifiable", false)
  
  -- Wait for keypress
  vim.fn.getchar()
  
  -- Refresh
  M.refresh()
end

return M opts.title
  if not title then
    title = vim.fn.input("Todo title: ")
    if title == "" then
      return
    end
  end
  
  local description = opts.description
  if not description and not opts.skip_description then
    description = vim.fn.input("Description (optional): ")
  end
  
  local priority = opts.priority
  if not priority and not opts.skip_priority then
    priority = vim.fn.input("Priority (H/M/L) [M]: ")
    if priority == "" then
      priority = "M"
    end
    priority = string.upper(string.sub(priority, 1, 1))
    if not (priority == "H" or priority == "M" or priority == "L") then
      priority = "M"
    end
  end
  
  local due_date = opts.due_date
  if not due_date and not opts.skip_due_date then
    due_date = vim.fn.input("Due date (YYYY-MM-DD, empty for none): ")
    -- Validate date format
    if due_date ~= "" and not due_date:match("^%d%d%d%d%-%d%d%-%d%d$") then
      vim.notify("Invalid date format. Use YYYY-MM-DD", vim.log.levels.ERROR)
      return
    end
  end
  
  local project = opts.project
  if not project and not opts.skip_project then
    project = vim.fn.input("Project (optional): ")
  end
  
  local tags = opts.tags
  if not tags and not opts.skip_tags then
    local tags_input = vim.fn.input("Tags (comma separated): ")
    if tags_input ~= "" then
      tags = vim.split(tags_input, ",")
      for i, tag in ipairs(tags) do
        tags[i] = vim.trim(tag)
      end
    else
      tags = {}
    end
  end
  
  -- Create the todo
  local todo = {
    title = title,
    description = description,
    priority = priority,
    due_date = due_date ~= "" and due_date or nil,
    tags = tags,
    project = project,
  }
  
  -- Save to storage
  storage.create_todo(todo)
  
  -- Refresh the view
  M.refresh()
end

-- Delete todo under cursor
function M.delete_todo_under_cursor()
  local id = get_todo_id_at_cursor()
  if not id then
    return
  end
  
  local confirm = vim.fn.input("Delete todo? (y/N): ")
  if confirm:lower() ~= "y" then
    return
  end
  
  storage.delete_todo(id)
  M.refresh()
end

-- Complete todo under cursor
function M.complete_todo_under_cursor()
  local id = get_todo_id_at_cursor()
  if not id then
    return
  end
  
  storage.complete_todo(id)
  M.refresh()
end

-- Edit todo under cursor
function M.edit_todo_under_cursor()
  local id = get_todo_id_at_cursor()
  if not id then
    return
  end
  
  local todo = storage.get_todo(id)
  if not todo then
    vim.notify("Todo not found", vim.log.levels.ERROR)
    return
  end
  
  -- Edit fields
  local title =
