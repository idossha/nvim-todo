local M = {}
local api = vim.api
local db = require("todo.db")
local config = nil

-- State variables
local buf, win = nil, nil
local current_tab = 1 -- 1: Active, 2: Completed, 3: Stats
local current_todos = {}
local selected_index = 1
local show_help = false

-- Get icons based on config
local function get_icons()
    if not config or not config.ui.icons then
        return {
            priority_low = " ",
            priority_medium = "! ",
            priority_high = "!! ",
            checkbox_empty = "[ ] ",
            checkbox_checked = "[x] ",
            tab_active = "Active ",
            tab_completed = "Completed ",
            tab_stats = "Stats ",
            due_date = "📅 ",
            tag = "#",
            project = "@"
        }
    else
        return {
            priority_low = " ",
            priority_medium = "! ",
            priority_high = "!! ",
            checkbox_empty = "□ ",
            checkbox_checked = "✓ ",
            tab_active = "📋 Active ",
            tab_completed = "✅ Completed ",
            tab_stats = "📊 Stats ",
            due_date = "📅 ",
            tag = "#",
            project = "@"
        }
    end
end

-- Format todo item for display
local function format_todo(todo)
    local icons = get_icons()
    local priority_icon = ""
    
    if todo.priority == 1 then
        priority_icon = icons.priority_medium
    elseif todo.priority == 2 then
        priority_icon = icons.priority_high
    else
        priority_icon = icons.priority_low
    end
    
    local checkbox = todo.is_completed == 1 and icons.checkbox_checked or icons.checkbox_empty
    
    local line = string.format("%s%s%s", checkbox, priority_icon, todo.text)
    
    -- Add due date if available
    if todo.due_date then
        local due_date = todo.due_date
        line = line .. " " .. icons.due_date .. due_date
    end
    
    return line
end

-- Create a new scratch buffer
local function create_buffer()
    buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_option(buf, "bufhidden", "wipe")
    api.nvim_buf_set_option(buf, "filetype", "todo")
    
    -- Set buffer-local keymappings
    local function set_keymap(key, cmd)
        api.nvim_buf_set_keymap(buf, "n", key, cmd, { noremap = true, silent = true })
    end
    
    set_keymap("j", ":lua require('todo.ui').move_cursor(1)<CR>")
    set_keymap("k", ":lua require('todo.ui').move_cursor(-1)<CR>")
    set_keymap("1", ":lua require('todo.ui').switch_tab(1)<CR>")
    set_keymap("2", ":lua require('todo.ui').switch_tab(2)<CR>")
    set_keymap("3", ":lua require('todo.ui').switch_tab(3)<CR>")
    set_keymap("a", ":lua require('todo.ui').add_todo()<CR>")
    set_keymap("c", ":lua require('todo.ui').complete_todo()<CR>")
    set_keymap("d", ":lua require('todo.ui').delete_todo()<CR>")
    set_keymap("e", ":lua require('todo.ui').edit_todo()<CR>")
    set_keymap("t", ":lua require('todo.ui').filter_by_tag()<CR>")
    set_keymap("p", ":lua require('todo.ui').filter_by_project()<CR>")
    set_keymap("s", ":lua require('todo.ui').search_todos()<CR>")
    set_keymap("r", ":lua require('todo.ui').refresh()<CR>")
    set_keymap("q", ":lua require('todo.ui').close()<CR>")
    set_keymap("?", ":lua require('todo.ui').toggle_help()<CR>")
    
    return buf
end

-- Create a window with the given buffer
local function create_window()
    local width = config.ui.width
    local height = config.ui.height
    local border = config.ui.border
    
    -- Calculate centered position
    local ui = vim.api.nvim_list_uis()[1]
    local win_width = math.min(width, ui.width)
    local win_height = math.min(height, ui.height)
    local row = math.floor((ui.height - win_height) / 2)
    local col = math.floor((ui.width - win_width) / 2)
    
    -- Window options
    local opts = {
        relative = "editor",
        width = win_width,
        height = win_height,
        row = row,
        col = col,
        style = "minimal",
        border = border
    }
    
    win = api.nvim_open_win(buf, true, opts)
    api.nvim_win_set_option(win, "cursorline", true)
    api.nvim_win_set_option(win, "wrap", true)
    api.nvim_win_set_option(win, "winhl", "Normal:TodoNormal,FloatBorder:TodoBorder")
    
    return win
end

-- Render the UI content
local function render()
    if not buf then return end
    
    api.nvim_buf_set_option(buf, "modifiable", true)
    
    local lines = {}
    local icons = get_icons()
    
    -- Add tabs
    table.insert(lines, string.format(
        "%s%s%s",
        current_tab == 1 and "[" .. icons.tab_active .. "]" or icons.tab_active, 
        current_tab == 2 and "[" .. icons.tab_completed .. "]" or icons.tab_completed,
        current_tab == 3 and "[" .. icons.tab_stats .. "]" or icons.tab_stats
    ))
    table.insert(lines, string.rep("-", config.ui.width - 2))
    
    -- Add help if enabled
    if show_help then
        table.insert(lines, "Keybindings:")
        table.insert(lines, "j/k: Navigate up/down   1/2/3: Switch tabs   a: Add todo")
        table.insert(lines, "c: Complete todo        d: Delete todo       e: Edit todo")
        table.insert(lines, "t: Filter by tag        p: Filter by project s: Search")
        table.insert(lines, "r: Refresh              q: Close window      ?: Toggle help")
        table.insert(lines, string.rep("-", config.ui.width - 2))
    end
    
    -- Add content based on current tab
    if current_tab == 1 or current_tab == 2 then
        -- Active or Completed todos
        if #current_todos == 0 then
            table.insert(lines, "No todos found.")
        else
            for i, todo in ipairs(current_todos) do
                table.insert(lines, format_todo(todo))
            end
        end
    elseif current_tab == 3 then
        -- Statistics
        local stats = db.get_stats()
        table.insert(lines, "📊 Todo Statistics:")
        table.insert(lines, "")
        table.insert(lines, string.format("Active todos: %d", stats.active))
        table.insert(lines, string.format("Completed todos: %d", stats.completed))
        table.insert(lines, string.format("Completed today: %d", stats.completed_today))
        table.insert(lines, string.format("Overdue: %d", stats.overdue))
        table.insert(lines, string.format("Due today: %d", stats.due_today))
        table.insert(lines, "")
        
        if #stats.projects > 0 then
            table.insert(lines, "Projects:")
            for _, project in ipairs(stats.projects) do
                table.insert(lines, "  @" .. project)
            end
            table.insert(lines, "")
        end
        
        if #stats.tags > 0 then
            table.insert(lines, "Tags:")
            for _, tag in ipairs(stats.tags) do
                table.insert(lines, "  #" .. tag)
            end
        end
    end
    
    -- Set the lines in the buffer
    api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    api.nvim_buf_set_option(buf, "modifiable", false)
    
    -- Set cursor position
    if current_tab ~= 3 and #current_todos > 0 then
        -- Add offset for header lines and ensure within bounds
        local header_offset = 2 + (show_help and 6 or 0)
        local cursor_line = math.min(header_offset + selected_index - 1, #lines)
        api.nvim_win_set_cursor(win, {cursor_line, 0})
    end
end

-- Open the UI
function M.open()
    -- Load config
    config = require("todo").config
    
    -- Create buffer and window if they don't exist
    if not buf or not api.nvim_buf_is_valid(buf) then
        buf = create_buffer()
    end
    
    if not win or not api.nvim_win_is_valid(win) then
        win = create_window()
    end
    
    -- Set initial state
    current_tab = 1
    selected_index = 1
    show_help = false
    
    -- Load active todos
    current_todos = db.get_active_todos()
    
    -- Render the UI
    render()
end

-- Close the UI
function M.close()
    if win and api.nvim_win_is_valid(win) then
        api.nvim_win_close(win, true)
        win = nil
    end
end

-- Move cursor up or down
function M.move_cursor(direction)
    if current_tab == 3 then return end
    
    selected_index = selected_index + direction
    
    -- Ensure within bounds
    if selected_index < 1 then
        selected_index = 1
    elseif selected_index > #current_todos then
        selected_index = #current_todos
    end
    
    render()
end

-- Switch between tabs
function M.switch_tab(tab)
    if tab < 1 or tab > 3 then return end
    
    current_tab = tab
    selected_index = 1
    
    -- Load appropriate data
    if tab == 1 then
        current_todos = db.get_active_todos()
    elseif tab == 2 then
        current_todos = db.get_completed_todos()
    end
    
    render()
end

-- Toggle help display
function M.toggle_help()
    show_help = not show_help
    render()
end

-- Add a new todo
function M.add_todo()
    vim.ui.input({ prompt = "New todo: " }, function(input)
        if input and input ~= "" then
            db.add_todo(input)
            M.refresh()
        end
    end)
end

-- Complete the selected todo
function M.complete_todo()
    if current_tab ~= 1 or #current_todos == 0 then return end
    
    local todo = current_todos[selected_index]
    if todo then
        db.complete_todo(todo.id)
        M.refresh()
    end
end

-- Delete the selected todo
function M.delete_todo()
    if #current_todos == 0 then return end
    
    local todo = current_todos[selected_index]
    if todo then
        db.delete_todo(todo.id)
        M.refresh()
    end
end

-- Edit the selected todo
function M.edit_todo()
    if #current_todos == 0 then return end
    
    local todo = current_todos[selected_index]
    if todo then
        vim.ui.input({ prompt = "Edit todo: ", default = todo.text }, function(input)
            if input and input ~= "" then
                db.update_todo(todo.id, input)
                M.refresh()
            end
        end)
    end
end

-- Filter todos by tag
function M.filter_by_tag()
    if current_tab == 3 then return end
    
    vim.ui.input({ prompt = "Filter by tag: " }, function(input)
        if input and input ~= "" then
            current_todos = db.filter_by_tag(input)
            selected_index = 1
            render()
        end
    end)
end

-- Filter todos by project
function M.filter_by_project()
    if current_tab == 3 then return end
    
    vim.ui.input({ prompt = "Filter by project: " }, function(input)
        if input and input ~= "" then
            current_todos = db.filter_by_project(input)
            selected_index = 1
            render()
        end
    end)
end

-- Search todos
function M.search_todos()
    if current_tab == 3 then return end
    
    vim.ui.input({ prompt = "Search: " }, function(input)
        if input and input ~= "" then
            current_todos = db.search_todos(input)
            selected_index = 1
            render()
        end
    end)
end

-- Refresh the current view
function M.refresh()
    if current_tab == 1 then
        current_todos = db.get_active_todos()
    elseif current_tab == 2 then
        current_todos = db.get_completed_todos()
    end
    
    -- Ensure selected index is valid
    if selected_index > #current_todos then
        selected_index = math.max(1, #current_todos)
    end
    
    render()
end

-- Show overdue todos
function M.show_overdue()
    current_tab = 1
    current_todos = db.get_overdue_todos()
    selected_index = 1
    
    if not buf or not api.nvim_buf_is_valid(buf) then
        M.open()
    else
        render()
    end
end

-- Show todos due today
function M.show_today()
    current_tab = 1
    current_todos = db.get_today_todos()
    selected_index = 1
    
    if not buf or not api.nvim_buf_is_valid(buf) then
        M.open()
    else
        render()
    end
end

-- Show statistics
function M.show_stats()
    current_tab = 3
    
    if not buf or not api.nvim_buf_is_valid(buf) then
        M.open()
    else
        render()
    end
end

return M
