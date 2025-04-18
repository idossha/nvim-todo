local M = {}

local api = vim.api
local db = require("todo.db")
local config = require("todo").config

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
  -- Create buffer if it doesn't exist
  if not M.state.buffer or not api.nvim_buf_is_valid(M.state.buffer) then
    M.state.buffer = api.nvim_create_buf(false, true)
    api.nvim_buf_set_option(M.state.buffer, "bufhidden", "wipe")
    api.nvim_buf_set_option(M.state.buffer, "filetype", "todo_stats")
  end
  
  -- Calculate window size and position
  local width = config.ui.width
  local height = 15  -- Smaller than the regular todo window
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
    title = " Todo Statistics ",
    title_pos = "center",
  }
  
  -- Create window if it doesn't exist or is not valid
  if not M.state.window or not api.nvim_win_is_valid(M.state.window) then
    M.state.window = api.nvim_open_win(M.state.buffer, true, opts)
    api.nvim_win_set_option(M.state.window, "winhighlight", "Normal:Normal,FloatBorder:FloatBorder")
  end
  
  -- Set buffer options
  api.nvim_buf_set_option(M.state.buffer, "modifiable", false)
  api.nvim_buf_set_option(M.state.buffer, "buftype", "nofile")
  
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
  
  -- Get stats from database
  local stats = db.get_stats()
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
    string.format("Total todos: %d", stats.total and stats.total[1].count or 0),
    string.format("Completed: %d (%.1f%%)", 
      stats.completed and stats.completed[1].count or 0,
      stats.total and stats.total[1].count > 0 
        and (stats.completed and stats.completed[1].count or 0) / stats.total[1].count * 100 
        or 0
    ),
    string.format("Pending: %d", stats.pending and stats.pending[1].count or 0),
    string.format("High priority: %d", stats.high_priority and stats.high_priority[1].count or 0),
    string.format("Overdue: %d", stats.overdue and stats.overdue[1].count or 0),
    string.format("Completed today: %d", stats.completed_today and stats.completed_today[1].count or 0),
    "",
    "--- By Project ---"
  }
  
  -- Add projects
  if stats.by_project and #stats.by_project > 0 then
    for _, row in ipairs(stats.by_project) do
      if row.project and row.project ~= "" then
        table.insert(lines, string.format("%s: %d", row.project, row.count))
      else
        table.insert(lines, string.format("(no project): %d", row.count))
      end
    end
  else
    table.insert(lines, "(no projects)")
  end
  
  table.insert(lines, "")
  table.insert(lines, "--- By Tag ---")
  
  -- Add tags
  if stats.by_tags and #stats.by_tags > 0 then
    for _, row in ipairs(stats.by_tags) do
      if row.tag and row.tag ~= "" then
        table.insert(lines, string.format("%s: %d", row.tag, row.count))
      end
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
  create_window()
  render_stats()
end

return M
