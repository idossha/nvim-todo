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
  require("todo.ui").refresh()
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
  local ui = require("todo.ui")
  
  local sort_options = {
    { key = "p", name = "Priority", field = "priority" },
    { key = "d", name = "Due Date", field = "due_date" },
    { key = "c", name = "Creation Date", field = "created_at" },
    { key = "t", name = "Title", field = "title" },
  }
  
  -- Display options
  api.nvim_buf_set_option(ui.state.buffer, "modifiable", true)
  api.nvim_buf_set_lines(ui.state.buffer, 0, -1, false, {
    "--- Sort by ---",
    "",
  })
  
  local lines = {}
  for _, option in ipairs(sort_options) do
    local selected = ui.state.sort.field == option.field
    local direction = ui.state.sort.ascending and "↑" or "↓"
    local line = string.format("%s: %s %s", option.key, option.name, selected and direction or "")
    table.insert(lines, line)
  end
  
  table.insert(lines, "")
  table.insert(lines, "r: Reverse order")
  table.insert(lines, "")
  table.insert(lines, "Press any key to sort, Esc to cancel")
  
  api.nvim_buf_set_lines(ui.state.buffer, 2, 2, false, lines)
  api.nvim_buf_set_option(ui.state.buffer, "modifiable", false)
  
  -- Wait for keypress
  local key = vim.fn.getchar()
  
  -- Convert to string
  if type(key) == "number" then
    key = vim.fn.nr2char(key)
  end
  
  -- Handle key
  if key == "\27" then -- Escape
    -- Cancel, just refresh
    ui.refresh()
    return
  elseif key == "r" then
    -- Reverse current sort
    ui.state.sort.ascending = not ui.state.sort.ascending
  else
    -- Look for sort option
    for _, option in ipairs(sort_options) do
      if key == option.key then
        if ui.state.sort.field == option.field then
          -- Toggle direction if same field
          ui.state.sort.ascending = not ui.state.sort.ascending
        else
          -- Set new field with default direction
          ui.state.sort.field = option.field
          ui.state.sort.ascending = true
        end
        break
      end
    end
  end
  
  -- Refresh with new sort
  ui.refresh()
end

-- Show filter menu
function M.show_filter_menu()
  local ui = require("todo.ui")
  
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
  api.nvim_buf_set_option(ui.state.buffer, "modifiable", true)
  api.nvim_buf_set_lines(ui.state.buffer, 0, -1, false, {
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
  
  api.nvim_buf_set_lines(ui.state.buffer, 2, 2, false, lines)
  api.nvim_buf_set_option(ui.state.buffer, "modifiable", false)
  
  -- Wait for keypress
  local key = vim.fn.getchar()
  
  -- Convert to string
  if type(key) == "number" then
    key = vim.fn.nr2char(key)
  end
  
  -- Handle key
  if key == "\27" then -- Escape
    -- Cancel, just refresh
    ui.refresh()
    return
  end
  
  -- Look for filter option
  for _, option in ipairs(filter_options) do
    if key == option.key then
      if option.filter == "tag_prompt" then
        -- Prompt for tag
        local tag = vim.fn.input("Filter by tag: ")
        if tag ~= "" then
          ui.state.filter = { tag = tag, completed = false }
        end
      elseif option.filter == "project_prompt" then
        -- Prompt for project
        local project = vim.fn.input("Filter by project: ")
        if project ~= "" then
          ui.state.filter = { project = project, completed = false }
        end
      else
        -- Apply filter
        ui.state.filter = option.filter
      end
      break
    end
  end
  
  -- Refresh with new filter
  ui.refresh()
end

-- Show help
function M.show_help()
  local ui = require("todo.ui")
  local mappings = config.mappings
  
  -- Display help
  api.nvim_buf_set_option(ui.state.buffer, "modifiable", true)
  api.nvim_buf_set_lines(ui.state.buffer, 0, -1, false, {
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
  api.nvim_buf_set_option(ui.state.buffer, "modifiable", false)
  
  -- Wait for keypress
  vim.fn.getchar()
  
  -- Refresh
  ui.refresh()
end

return M
