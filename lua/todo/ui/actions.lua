local M = {}

local api = vim.api
local storage = require("todo.storage")
local config = require("todo").config

-- Helper function to get todo ID under cursor
local function get_todo_id_at_cursor()
  local ui = require("todo.ui")
  
  if not ui.is_open() then
    return nil
  end
  
  local line = api.nvim_win_get_cursor(ui.state.window)[1]
  local line_to_id = api.nvim_buf_get_var(ui.state.buffer, "line_to_id")
  
  return line_to_id[line]
end

-- Add a new todo
function M.add_todo(opts)
  opts = opts or {}
  
  -- Create input fields
  local title = opts.title
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
  require("todo.ui").refresh()
end

-- Delete todo under cursor
function M.delete_todo_under_cursor(skip_confirmation)
  local api = vim.api
  local state = require("todo.ui").state
  local storage = require("todo.storage")
  
  if not state.buffer or not api.nvim_buf_is_valid(state.buffer) then
    return
  end
  
  local line = api.nvim_win_get_cursor(state.window)[1]
  local line_to_id = api.nvim_buf_get_var(state.buffer, "line_to_id") or {}
  local id = line_to_id[line]
  
  if not id then
    return
  end
  
  -- Skip confirmation if called from double press
  if skip_confirmation then
    storage.delete_todo(id)
    require("todo.ui").refresh()
    return
  end
  
  -- Otherwise show confirmation prompt
  vim.ui.input({
    prompt = "Delete this todo? (y/n): ",
    default = "n"
  }, function(input)
    if input and input:lower() == "y" then
      storage.delete_todo(id)
      require("todo.ui").refresh()
    end
  end)
end

-- Complete todo under cursor
function M.complete_todo_under_cursor()
  local id = get_todo_id_at_cursor()
  if not id then
    return
  end
  
  storage.complete_todo(id)
  require("todo.ui").refresh()
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
  require("todo.ui").refresh()
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
  require("todo.ui").refresh()
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
  require("todo.ui").refresh()
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
  require("todo.ui").refresh()
end

-- Show sort menu
function M.show_sort_menu()
  local state = require("todo.ui").get_state()
  
  -- Wait for keypress
  local key = vim.fn.getchar()
  
  -- Convert to string
  if type(key) == "number" then
    key = vim.fn.nr2char(key)
  end
  
  local sort_options = {
    ["d"] = "Date",
    ["p"] = "Priority",
    ["j"] = "Project"
  }
  
  if sort_options[key] then
    state.current_sort = sort_options[key]
    -- Toggle sort direction if same sort is selected
    if state.last_sort == sort_options[key] then
      state.sort_ascending = not state.sort_ascending
    else
      state.sort_ascending = true
    end
    state.last_sort = sort_options[key]
    
    -- Refresh the UI (sorting happens in render)
    require("todo.ui").refresh()
  end
end

-- Show filter menu
function M.show_filter_menu()
  local state = require("todo.ui").get_state()
  
  -- Wait for keypress
  local key = vim.fn.getchar()
  
  -- Convert to string
  if type(key) == "number" then
    key = vim.fn.nr2char(key)
  end
  
  -- Handle priority filter
  if key == "p" then
    -- Wait for priority keypress
    local priority_key = vim.fn.getchar()
    if type(priority_key) == "number" then
      priority_key = vim.fn.nr2char(priority_key)
    end
    
    local priority_options = {
      ["h"] = "High",
      ["m"] = "Medium",
      ["l"] = "Low"
    }
    
    if priority_options[priority_key] then
      state.current_filter = "priority:" .. priority_options[priority_key]
      require("todo.ui").refresh()
    end
  else
    local filter_options = {
      ["a"] = "all",  -- Show all tasks
      ["c"] = "completed",
      ["o"] = "open",
      ["t"] = "tags",
      ["j"] = "project"
    }
    
    if filter_options[key] then
      state.current_filter = filter_options[key]
      require("todo.ui").refresh()
    end
  end
end

-- Show help
function M.show_help()
  local ui = require("todo.ui")
  local mappings = config.mappings
  
  -- Check if help is already shown
  if ui.state.showing_help then
    -- Help is shown, close it
    ui.state.showing_help = false
    require("todo.ui").refresh()
    return
  end
  
  -- Help is not shown, display it
  ui.state.showing_help = true
  
  -- Display help table
  api.nvim_buf_set_option(ui.state.buffer, "modifiable", true)
  
  -- Create help table with box drawing characters
  local help_lines = {
    "╭───────────────────────────────╮",
    "│        Todo.nvim Help         │",
    "├───────────────────────────────┤",
    string.format("│ %s: Add new todo           │", mappings.add),
    string.format("│ %s: Delete todo            │", mappings.delete),
    string.format("│ %s: Complete todo          │", mappings.complete),
    string.format("│ %s: Edit todo              │", mappings.edit),
    string.format("│ %s: Edit tags              │", mappings.tags),
    string.format("│ %s: Set priority           │", mappings.priority),
    string.format("│ %s: Set due date           │", mappings.due_date),
    string.format("│ %s: Sort todos             │", mappings.sort),
    string.format("│ %s: Filter todos           │", mappings.filter),
    string.format("│ %s: Close window           │", mappings.close),
    "╰───────────────────────────────╯",
    "",
    "Press 'h' to close"
  }
  
  -- Set help lines
  api.nvim_buf_set_lines(ui.state.buffer, 0, -1, false, help_lines)
  api.nvim_buf_set_option(ui.state.buffer, "modifiable", false)
  
  -- Add highlights
  local ns_id = api.nvim_create_namespace("TodoHelp")
  api.nvim_buf_clear_namespace(ui.state.buffer, ns_id, 0, -1)
  
  -- Highlight the box
  for i = 1, #help_lines do
    api.nvim_buf_add_highlight(ui.state.buffer, ns_id, "TodoHelpBorder", i - 1, 0, -1)
  end
  
  -- Highlight the title
  api.nvim_buf_add_highlight(ui.state.buffer, ns_id, "TodoHelpTitle", 1, 0, -1)
  
  -- Highlight the commands
  for i = 4, #help_lines - 2 do
    api.nvim_buf_add_highlight(ui.state.buffer, ns_id, "TodoHelpCommand", i - 1, 0, -1)
  end
end

return M
