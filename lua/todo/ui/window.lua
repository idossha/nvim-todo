local M = {}

local api = vim.api
local config = require("todo").config
local actions = require("todo.ui.actions")

-- Function to update window size and position
local function update_window_size(state)
  if not state.window or not api.nvim_win_is_valid(state.window) then
    return
  end

  local width = config.ui.width
  local height = config.ui.height
  
  -- Convert percentages to actual dimensions
  width = math.floor(vim.o.columns * width)
  height = math.floor(vim.o.lines * height)
  
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  
  -- Update window options
  api.nvim_win_set_config(state.window, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = config.ui.border,
    title = " Todo List ",
    title_pos = "center",
  })
end

-- Create the floating window for todos
function M.create(state)
  -- Create buffer if it doesn't exist
  if not state.buffer or not api.nvim_buf_is_valid(state.buffer) then
    state.buffer = api.nvim_create_buf(false, true)
    api.nvim_buf_set_option(state.buffer, "bufhidden", "wipe")
    api.nvim_buf_set_option(state.buffer, "filetype", "todo")
  end
  
  -- Calculate initial window size and position
  local width = math.floor(vim.o.columns * config.ui.width)
  local height = math.floor(vim.o.lines * config.ui.height)
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
  if not state.window or not api.nvim_win_is_valid(state.window) then
    state.window = api.nvim_open_win(state.buffer, true, opts)
    api.nvim_win_set_option(state.window, "winhighlight", "Normal:Normal,FloatBorder:FloatBorder")
    api.nvim_win_set_option(state.window, "cursorline", true)
    
    -- Create autocommand to handle window resizing
    local group = api.nvim_create_augroup("TodoWindowResize", { clear = true })
    api.nvim_create_autocmd("VimResized", {
      group = group,
      callback = function()
        update_window_size(state)
      end,
    })
  end
  
  -- Set buffer options
  api.nvim_buf_set_option(state.buffer, "modifiable", false)
  api.nvim_buf_set_option(state.buffer, "buftype", "nofile")
  
  -- Set up keybindings
  M.setup_keymaps(state)
end

-- Set up keybindings for the window
function M.setup_keymaps(state)
  local mappings = {
    [config.mappings.add] = actions.add_todo,
    [config.mappings.delete] = actions.delete_todo_under_cursor,
    [config.mappings.complete] = actions.complete_todo_under_cursor,
    [config.mappings.edit] = actions.edit_todo_under_cursor,
    [config.mappings.tags] = actions.edit_tags,
    [config.mappings.priority] = actions.set_priority,
    [config.mappings.due_date] = actions.set_due_date,
    [config.mappings.sort] = actions.show_sort_menu,
    [config.mappings.filter] = actions.show_filter_menu,
    [config.mappings.close] = function() require("todo.ui").close() end,
    [config.mappings.help] = actions.show_help,
  }
  
  for key, func in pairs(mappings) do
    api.nvim_buf_set_keymap(state.buffer, "n", key, "", {
      noremap = true,
      silent = true,
      callback = func,
    })
  end
end

return M
