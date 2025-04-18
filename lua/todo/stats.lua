local M = {}

local api = vim.api
local storage = require("todo.storage")
local config = require("todo").config
local ui = require("todo.ui")


-- State
M.state = {
  buffer = nil,
  window = nil,
}

-- Check if the stats window is open
local function is_open()
  return M.state.buffer ~= nil and api.nvim_buf_is_valid(M.state.buffer) and
         M.state.window ~= nil and api.nvim_win_is_valid(M.state.window)
end

-- Create stats window
local function create_window()
  local width = math.floor(vim.o.columns * 0.4)  -- 40% of screen width
  local height = math.floor(vim.o.lines * 0.4)   -- 40% of screen height
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  
  -- Create buffer
  M.state.buffer = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(M.state.buffer, "bufhidden", "wipe")
  api.nvim_buf_set_option(M.state.buffer, "filetype", "todo_stats")
  
  -- Create window
  M.state.window = api.nvim_open_win(M.state.buffer, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Todo Statistics ",
    title_pos = "center",
  })
  
  api.nvim_win_set_option(M.state.window, "winhighlight", "Normal:Normal,FloatBorder:FloatBorder")
  
  -- Set up keybindings
  api.nvim_buf_set_keymap(M.state.buffer, "n", "q", "", {
    noremap = true,
    silent = true,
    callback = function()
      api.nvim_win_close(M.state.window, true)
      M.state.window = nil
      M.state.buffer = nil
    end,
  })
end

-- Render statistics
local function render_stats()
  if not is_open() then
    return
  end
  
  -- Get stats from storage
  local stats = storage.get_stats()
  if not stats then
    api.nvim_buf_set_option(M.state.buffer, "modifiable", true)
    api.nvim_buf_set_lines(M.state.buffer, 0, -1, false, {
      "Could not load statistics",
      "",
      "Press 'q' to close this window"
    })
    api.nvim_buf_set_option(M.state.buffer, "modifiable", false)
    return
  end
  
  -- Format stats
  local lines = {
    "--- Todo Statistics ---",
    "",
    string.format("Total todos: %d", stats.total or 0),
    string.format("Completed: %d (%.1f%%)", 
      stats.completed or 0,
      stats.total > 0 
        and (stats.completed or 0) / stats.total * 100 
        or 0
    ),
    string.format("Pending: %d", stats.pending or 0),
    string.format("High priority: %d", stats.high_priority or 0),
    string.format("Overdue: %d", stats.overdue or 0),
    string.format("Completed today: %d", stats.completed_today or 0),
    "",
    "--- By Project ---"
  }
  
  -- Add projects
  local project_data = {}
  for project, count in pairs(stats.by_project or {}) do
    table.insert(project_data, {project = project, count = count})
  end
  
  -- Sort by count (descending)
  table.sort(project_data, function(a, b) return a.count > b.count end)
  
  if #project_data > 0 then
    for _, data in ipairs(project_data) do
      table.insert(lines, string.format("%s: %d", data.project, data.count))
    end
  else
    table.insert(lines, "(no projects)")
  end
  
  table.insert(lines, "")
  table.insert(lines, "--- By Tag ---")
  
  -- Add tags
  local tag_data = {}
  for tag, count in pairs(stats.by_tags or {}) do
    table.insert(tag_data, {tag = tag, count = count})
  end
  
  -- Sort by count (descending)
  table.sort(tag_data, function(a, b) return a.count > b.count end)
  
  if #tag_data > 0 then
    for _, data in ipairs(tag_data) do
      table.insert(lines, string.format("%s: %d", data.tag, data.count))
    end
  else
    table.insert(lines, "(no tags)")
  end
  
  table.insert(lines, "")
  table.insert(lines, "Press 'q' to close this window")
  
  -- Update buffer
  api.nvim_buf_set_option(M.state.buffer, "modifiable", true)
  api.nvim_buf_set_lines(M.state.buffer, 0, -1, false, lines)
  api.nvim_buf_set_option(M.state.buffer, "modifiable", false)
end

-- Show statistics window
function M.show()
  if is_open() then
    api.nvim_win_close(M.state.window, true)
    M.state.window = nil
    M.state.buffer = nil
    return
  end
  
  create_window()
  render_stats()
end

return M
