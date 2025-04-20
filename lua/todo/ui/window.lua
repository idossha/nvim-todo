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
  
  -- Ensure window doesn't cover the entire buffer
  width = math.min(width, math.floor(vim.o.columns * 0.8))
  height = math.min(height, math.floor(vim.o.lines * 0.8))
  
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
  
  -- Ensure window doesn't cover the entire buffer
  width = math.min(width, math.floor(vim.o.columns * 0.8))
  height = math.min(height, math.floor(vim.o.lines * 0.8))
  
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
  }
  
  for key, func in pairs(mappings) do
    api.nvim_buf_set_keymap(state.buffer, "n", key, "", {
      noremap = true,
      silent = true,
      callback = func,
    })
  end

  -- Set up help keybind
  api.nvim_buf_set_keymap(state.buffer, "n", "h", "", {
    noremap = true,
    silent = true,
    callback = function()
      -- Create help window
      local width = math.floor(vim.o.columns * 0.4)
      local height = math.floor(vim.o.lines * 0.4)
      local row = math.floor((vim.o.lines - height) / 2)
      local col = math.floor((vim.o.columns - width) / 2)
      
      local help_buf = api.nvim_create_buf(false, true)
      local help_win = api.nvim_open_win(help_buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        style = "minimal",
        border = "rounded",
        title = " Todo Commands ",
        title_pos = "center",
      })
      
      -- Set up help content
      local help_lines = {
        "Todo Window Commands:",
        "",
        string.format("%-10s %s", "a", "Add new todo (opens input prompt)"),
        string.format("%-10s %s", "d", "Delete todo under cursor"),
        string.format("%-10s %s", "c", "Complete todo under cursor"),
        string.format("%-10s %s", "e", "Edit todo under cursor (opens input prompt)"),
        string.format("%-10s %s", "t", "Edit tags (opens tag selection menu)"),
        string.format("%-10s %s", "p", "Set priority (opens priority selection: H/M/L)"),
        string.format("%-10s %s", "D", "Set due date (opens date picker)"),
        string.format("%-10s %s", "s", "Sort todos (opens sort menu: by date/priority/project)"),
        string.format("%-10s %s", "f", "Filter todos (opens filter menu: by status/tags/project)"),
        string.format("%-10s %s", "q", "Close todo window"),
        string.format("%-10s %s", "h", "Show this help"),
        "",
        "Global Commands:",
        "",
        string.format("%-10s %s", "<leader>to", "Open todo list"),
        string.format("%-10s %s", "<leader>ta", "Add new todo (opens input prompt)"),
        string.format("%-10s %s", "<leader>ts", "Show todo statistics"),
        "",
        "Press 'q' to close this window"
      }
      
      -- Add highlights
      api.nvim_buf_set_option(help_buf, "modifiable", true)
      api.nvim_buf_set_lines(help_buf, 0, -1, false, help_lines)
      api.nvim_buf_set_option(help_buf, "modifiable", false)
      
      -- Add highlights for headers
      local ns_id = api.nvim_create_namespace("TodoHelp")
      api.nvim_buf_add_highlight(help_buf, ns_id, "Title", 0, 0, -1)
      api.nvim_buf_add_highlight(help_buf, ns_id, "Title", 14, 0, -1)
      
      -- Add keybind to close help window
      api.nvim_buf_set_keymap(help_buf, "n", "q", "", {
        noremap = true,
        silent = true,
        callback = function()
          api.nvim_win_close(help_win, true)
        end,
      })
    end,
  })

  -- Set up description preview
  api.nvim_create_autocmd("CursorMoved", {
    buffer = state.buffer,
    callback = function()
      local line = api.nvim_win_get_cursor(state.window)[1]
      local line_to_id = api.nvim_buf_get_var(state.buffer, "line_to_id")
      local id = line_to_id[line]
      
      if id then
        local todo = require("todo.storage").get_todo(id)
        if todo and todo.description and todo.description:match("%S") then
          -- Get current lines
          local lines = api.nvim_buf_get_lines(state.buffer, 0, -1, false)
          
          -- Check if description is already shown
          if not state.showing_description then
            -- Insert description after the current line
            table.insert(lines, line + 1, "  └─ " .. todo.description)
            state.showing_description = true
            state.description_line = line + 1
          else
            -- Update existing description
            lines[state.description_line] = "  └─ " .. todo.description
          end
          
          -- Update buffer
          api.nvim_buf_set_option(state.buffer, "modifiable", true)
          api.nvim_buf_set_lines(state.buffer, 0, -1, false, lines)
          api.nvim_buf_set_option(state.buffer, "modifiable", false)
          
          -- Add highlight for description
          local ns_id = api.nvim_create_namespace("TodoDescription")
          api.nvim_buf_clear_namespace(state.buffer, ns_id, 0, -1)
          api.nvim_buf_add_highlight(state.buffer, ns_id, "Comment", state.description_line - 1, 0, -1)
        elseif state.showing_description then
          -- Remove description
          local lines = api.nvim_buf_get_lines(state.buffer, 0, -1, false)
          table.remove(lines, state.description_line)
          
          -- Update buffer
          api.nvim_buf_set_option(state.buffer, "modifiable", true)
          api.nvim_buf_set_lines(state.buffer, 0, -1, false, lines)
          api.nvim_buf_set_option(state.buffer, "modifiable", false)
          
          state.showing_description = false
          state.description_line = nil
        end
      end
    end,
  })
end

return M
