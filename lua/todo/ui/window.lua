local M = {}

local api = vim.api
local config = require("todo").config
local actions = require("todo.ui.actions")

-- Helper function to get window title based on current state
local function get_window_title(state)
  local title = " Todo List "
  
  -- Add filter status
  if state.current_filter then
    title = title .. "| Filter: " .. state.current_filter
  end
  
  -- Add sort status with direction
  if state.current_sort then
    local sort_direction = state.sort_ascending and "↑" or "↓"
    title = title .. " | Sort: " .. state.current_sort .. " " .. sort_direction
  end
  
  -- Add todo count
  local todo_count = #api.nvim_buf_get_lines(state.buffer, 0, -1, false)
  title = title .. " | " .. todo_count .. " todos"
  
  return title
end

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
  local todo_count = #api.nvim_buf_get_lines(state.buffer, 0, -1, false)
  table.insert(status, todo_count .. " todos")
  
  return table.concat(status, " | ")
end

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
    title = " todo.nvim ",
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
    -- Initialize line_to_id variable
    api.nvim_buf_set_var(state.buffer, "line_to_id", {})
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
    title = " todo.nvim ",
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
  -- Track last key press and time for double press detection
  local last_key = nil
  local last_key_time = 0
  local DOUBLE_PRESS_TIMEOUT = 500 -- milliseconds
  
  -- Add keymaps for todo actions
  api.nvim_buf_set_keymap(state.buffer, "n", config.mappings.add, "", {
    noremap = true,
    silent = true,
    callback = function()
      require("todo.ui.actions").add_todo()
    end
  })
  
  -- Handle delete with double press
  api.nvim_buf_set_keymap(state.buffer, "n", config.mappings.delete, "", {
    noremap = true,
    silent = true,
    callback = function()
      local current_time = vim.loop.now()
      if last_key == "d" and (current_time - last_key_time) < DOUBLE_PRESS_TIMEOUT then
        -- Double press detected, delete immediately without confirmation
        require("todo.ui.actions").delete_todo_under_cursor(true)
        last_key = nil
        last_key_time = 0
      else
        -- First press, just record it
        last_key = "d"
        last_key_time = current_time
      end
    end
  })
  
  -- Clear last key if another key is pressed
  api.nvim_buf_set_keymap(state.buffer, "n", "<any>", "", {
    noremap = true,
    silent = true,
    callback = function()
      last_key = nil
      last_key_time = 0
    end
  })
  
  api.nvim_buf_set_keymap(state.buffer, "n", config.mappings.complete, "", {
    noremap = true,
    silent = true,
    callback = function()
      require("todo.ui.actions").complete_todo_under_cursor()
    end
  })
  
  api.nvim_buf_set_keymap(state.buffer, "n", config.mappings.edit, "", {
    noremap = true,
    silent = true,
    callback = function()
      require("todo.ui.actions").edit_todo_under_cursor()
    end
  })
  
  api.nvim_buf_set_keymap(state.buffer, "n", config.mappings.tags, "", {
    noremap = true,
    silent = true,
    callback = function()
      require("todo.ui.actions").edit_tags()
    end
  })
  
  api.nvim_buf_set_keymap(state.buffer, "n", config.mappings.priority, "", {
    noremap = true,
    silent = true,
    callback = function()
      require("todo.ui.actions").set_priority()
    end
  })
  
  api.nvim_buf_set_keymap(state.buffer, "n", config.mappings.due_date, "", {
    noremap = true,
    silent = true,
    callback = function()
      require("todo.ui.actions").set_due_date()
    end
  })
  
  api.nvim_buf_set_keymap(state.buffer, "n", config.mappings.sort, "", {
    noremap = true,
    silent = true,
    callback = function()
      require("todo.ui.actions").show_sort_menu()
    end
  })
  
  api.nvim_buf_set_keymap(state.buffer, "n", config.mappings.filter, "", {
    noremap = true,
    silent = true,
    callback = function()
      require("todo.ui.actions").show_filter_menu()
    end
  })
  
  api.nvim_buf_set_keymap(state.buffer, "n", config.mappings.close, "", {
    noremap = true,
    silent = true,
    callback = function()
      require("todo.ui").close()
    end
  })
  
  -- Add help keybinding
  api.nvim_buf_set_keymap(state.buffer, "n", "h", "", {
    noremap = true,
    silent = true,
    callback = function()
      require("todo.ui.actions").show_help()
    end
  })
  
  -- Set up description preview
  api.nvim_create_autocmd("CursorMoved", {
    buffer = state.buffer,
    callback = function()
      local line = api.nvim_win_get_cursor(state.window)[1]
      local line_to_id = api.nvim_buf_get_var(state.buffer, "line_to_id") or {}
      local id = line_to_id[line]
      
      if id then
        local todo = require("todo.storage").get_todo(id)
        if todo and todo.description and todo.description:match("%S") then
          -- Get current lines
          local lines = api.nvim_buf_get_lines(state.buffer, 0, -1, false)
          
          -- Check if description is already shown
          if state.showing_description then
            -- Remove old description
            table.remove(lines, state.description_line)
            state.showing_description = false
            state.description_line = nil
          end
          
          -- Insert new description
          table.insert(lines, line + 1, "  └─ " .. todo.description)
          state.showing_description = true
          state.description_line = line + 1
          
          -- Update buffer
          api.nvim_buf_set_option(state.buffer, "modifiable", true)
          api.nvim_buf_set_lines(state.buffer, 0, -1, false, lines)
          api.nvim_buf_set_option(state.buffer, "modifiable", false)
          
          -- Add highlight for description without affecting other highlights
          local ns_id = api.nvim_create_namespace("TodoDescription")
          api.nvim_buf_clear_namespace(state.buffer, ns_id, 0, -1)
          api.nvim_buf_add_highlight(state.buffer, ns_id, "Comment", state.description_line - 1, 0, -1)
          
          -- Re-apply all other highlights
          require("todo.ui.render").apply_highlighting(state)
        elseif state.showing_description then
          -- Remove description if no longer needed
          local lines = api.nvim_buf_get_lines(state.buffer, 0, -1, false)
          table.remove(lines, state.description_line)
          state.showing_description = false
          state.description_line = nil
          
          -- Update buffer
          api.nvim_buf_set_option(state.buffer, "modifiable", true)
          api.nvim_buf_set_lines(state.buffer, 0, -1, false, lines)
          api.nvim_buf_set_option(state.buffer, "modifiable", false)
          
          -- Re-apply all highlights
          require("todo.ui.render").apply_highlighting(state)
        end
      elseif state.showing_description then
        -- Remove description if cursor moved to a non-todo line
        local lines = api.nvim_buf_get_lines(state.buffer, 0, -1, false)
        table.remove(lines, state.description_line)
        state.showing_description = false
        state.description_line = nil
        
        -- Update buffer
        api.nvim_buf_set_option(state.buffer, "modifiable", true)
        api.nvim_buf_set_lines(state.buffer, 0, -1, false, lines)
        api.nvim_buf_set_option(state.buffer, "modifiable", false)
        
        -- Re-apply all highlights
        require("todo.ui.render").apply_highlighting(state)
      end
    end
  })
end

return M
