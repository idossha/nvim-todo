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

-- Function to update window size and position
local function update_window_size(state)
  if not state.window or not api.nvim_win_is_valid(state.window) then
    return
  end

  local width = config.ui.width
  local height = config.ui.height
  
  -- Convert percentages to actual dimensions
  width = math.floor(vim.o.columns * width)
  height = math.min(height, math.floor(vim.o.lines * 0.8))
  
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
    title = get_window_title(state),
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
    title = get_window_title(state),
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
      callback = function()
        func()
        -- Update window title after filter/sort changes
        if key == config.mappings.sort or key == config.mappings.filter then
          api.nvim_win_set_config(state.window, {
            title = get_window_title(state),
            title_pos = "center",
          })
        end
      end,
    })
  end

  -- Set up help keybind
  api.nvim_buf_set_keymap(state.buffer, "n", "h", "", {
    noremap = true,
    silent = true,
    callback = function()
      local lines = api.nvim_buf_get_lines(state.buffer, 0, -1, false)
      
      -- Check if help section is already shown
      if state.showing_help then
        -- Remove help section
        local help_start = state.help_start_line
        local help_end = state.help_end_line
        for i = help_end, help_start, -1 do
          table.remove(lines, i)
        end
        state.showing_help = false
        state.help_start_line = nil
        state.help_end_line = nil
      else
        -- Add help section
        local help_lines = {
          "╭───────────────────────────────────────────────╮",
          "│              Todo Commands                    │",
          "├───────────────────────────────────────────────┤",
          "│  a  │ Add new todo                           │",
          "│  d  │ Delete todo                            │",
          "│  c  │ Complete todo                          │",
          "│  e  │ Edit todo                              │",
          "│  t  │ Edit tags                              │",
          "│  p  │ Set priority (H/M/L)                   │",
          "│  D  │ Set due date                           │",
          "│  s  │ Sort todos:                            │",
          "│     │  1. By date (created/due)              │",
          "│     │  2. By priority (H/M/L)                │",
          "│     │  3. By project                         │",
          "│  f  │ Filter todos:                          │",
          "│     │  1. By status (open/completed)         │",
          "│     │  2. By tags                            │",
          "│     │  3. By project                         │",
          "│     │  4. By priority                        │",
          "│     │  5. Clear filters                      │",
          "│  q  │ Close window                           │",
          "│  h  │ Toggle help                            │",
          "├───────────────────────────────────────────────┤",
          "│ <leader>to │ Open todo list                  │",
          "│ <leader>ta │ Add new todo                    │",
          "│ <leader>ts │ Show statistics                 │",
          "╰───────────────────────────────────────────────╯"
        }
        
        -- Insert help section at the top
        for i, line in ipairs(help_lines) do
          table.insert(lines, i, line)
        end
        
        state.showing_help = true
        state.help_start_line = 1
        state.help_end_line = #help_lines
      end
      
      -- Update buffer
      api.nvim_buf_set_option(state.buffer, "modifiable", true)
      api.nvim_buf_set_lines(state.buffer, 0, -1, false, lines)
      api.nvim_buf_set_option(state.buffer, "modifiable", false)
      
      -- Add highlights
      if state.showing_help then
        local ns_id = api.nvim_create_namespace("TodoHelp")
        api.nvim_buf_clear_namespace(state.buffer, ns_id, 0, -1)
        
        -- Highlight borders and headers
        api.nvim_buf_add_highlight(state.buffer, ns_id, "TodoHelpBorder", 0, 0, -1)
        api.nvim_buf_add_highlight(state.buffer, ns_id, "TodoHelpBorder", 2, 0, -1)
        api.nvim_buf_add_highlight(state.buffer, ns_id, "TodoHelpBorder", 21, 0, -1)
        api.nvim_buf_add_highlight(state.buffer, ns_id, "TodoHelpBorder", 24, 0, -1)
        
        -- Highlight command keys
        for i = 3, 20 do
          if i ~= 10 and i ~= 11 and i ~= 12 and i ~= 14 and i ~= 15 and i ~= 16 and i ~= 17 and i ~= 18 then
            api.nvim_buf_add_highlight(state.buffer, ns_id, "TodoHelpKey", i, 2, 5)
          end
        end
        for i = 22, 23 do
          api.nvim_buf_add_highlight(state.buffer, ns_id, "TodoHelpKey", i, 2, 12)
        end
      end
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
