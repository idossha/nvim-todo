local M = {}

-- Import required modules
local config = require('todo.config')
local db = require('todo.db')
local utils = require('todo.utils')

-- UI state
local state = {
    buf = nil,              -- Buffer ID
    win = nil,              -- Window ID
    section = "active",     -- Current section: "active", "completed", "stats"
    todos = {},             -- Current todos
    selected_idx = 1,       -- Currently selected todo index
    filter = {              -- Current filters
        tag = nil,
        project = nil,
        search = nil
    },
    metadata = {            -- Available metadata
        tags = {},
        projects = {}
    },
    show_help = false       -- Whether to show help
}

-- UI components
local ui = {
    symbols = {
        checkbox_empty = "[ ]",
        checkbox_checked = "[✓]",
        priority = {
            [0] = "",
            [1] = "!",
            [2] = "!!"
        },
        stats = "📊",
        tag = "#",
        project = "@",
        due = "📅",
        border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }
    },
    colors = {
        title = "TodoTitle",
        checkbox = "TodoCheckbox",
        checkbox_checked = "TodoCheckboxChecked",
        priority = {
            [0] = "TodoPriorityNormal",
            [1] = "TodoPriorityMedium",
            [2] = "TodoPriorityHigh"
        },
        tag = "TodoTag",
        project = "TodoProject",
        due = "TodoDue",
        due_soon = "TodoDueSoon",
        overdue = "TodoOverdue",
        stats = "TodoStats",
        help = "TodoHelp",
        section = "TodoSection",
        section_active = "TodoSectionActive"
    }
}

-- Set up highlight groups
local function setup_highlights()
    vim.cmd([[
        highlight default TodoTitle guifg=#61afef gui=bold
        highlight default TodoCheckbox guifg=#98c379
        highlight default TodoCheckboxChecked guifg=#98c379 gui=italic
        highlight default TodoPriorityNormal guifg=#abb2bf
        highlight default TodoPriorityMedium guifg=#e5c07b
        highlight default TodoPriorityHigh guifg=#e06c75 gui=bold
        highlight default TodoTag guifg=#56b6c2
        highlight default TodoProject guifg=#c678dd
        highlight default TodoDue guifg=#56b6c2
        highlight default TodoDueSoon guifg=#e5c07b
        highlight default TodoOverdue guifg=#e06c75
        highlight default TodoStats guifg=#61afef
        highlight default TodoHelp guifg=#5c6370
        highlight default TodoSection guifg=#5c6370
        highlight default TodoSectionActive guifg=#abb2bf gui=bold
    ]])
end

-- Create floating window for Todo UI
local function create_float_win()
    local cfg = config.get().ui
    local width = cfg.width
    local height = cfg.height
    local border = cfg.border
    
    -- Calculate position
    local vim_width = vim.api.nvim_get_option("columns")
    local vim_height = vim.api.nvim_get_option("lines")
    local row = math.floor((vim_height - height) / 2)
    local col = math.floor((vim_width - width) / 2)
    
    -- Create buffer
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
    
    -- Window options
    local win_opts = {
        style = "minimal",
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        border = border
    }
    
    if border == "rounded" then
        win_opts.border = "rounded"
    elseif border == "single" then
        win_opts.border = "single"
    elseif border == "double" then
        win_opts.border = "double"
    elseif border == "none" then
        win_opts.border = "none"
    else
        win_opts.border = ui.symbols.border
    end
    
    -- Create window
    local win = vim.api.nvim_open_win(buf, true, win_opts)
    
    -- Set window options
    vim.api.nvim_win_set_option(win, "winblend", 0)
    vim.api.nvim_win_set_option(win, "cursorline", true)
    vim.api.nvim_win_set_option(win, "signcolumn", "no")
    vim.api.nvim_win_set_option(win, "wrap", false)
    
    -- Remember window and buffer
    state.buf = buf
    state.win = win
    
    return buf, win
end

-- Render UI based on current state
local function render()
    if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
        return
    end
    
    -- Get todos based on current section and filters
    local lines = {}
    local highlights = {}
    
    -- Clear buffer
    vim.api.nvim_buf_set_option(state.buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, {})
    
    -- Add section headers
    table.insert(lines, "TODO MANAGER")
    table.insert(highlights, {line = 0, col_start = 0, col_end = 12, group = ui.colors.title})
    
    -- Section tabs
    local sections = {
        {"Active Todos", "active"},
        {"Completed Todos", "completed"},
        {"Statistics", "stats"}
    }
    
    local section_line = ""
    local col_start = 0
    
    for i, section in ipairs(sections) do
        local label = section[1]
        local section_id = section[2]
        
        if i > 1 then
            section_line = section_line .. " | "
            col_start = col_start + 3
        end
        
        section_line = section_line .. label
        
        local color = state.section == section_id and ui.colors.section_active or ui.colors.section
        table.insert(highlights, {
            line = 1, 
            col_start = col_start, 
            col_end = col_start + #label, 
            group = color
        })
        
        col_start = col_start + #label
    end
    
    table.insert(lines, section_line)
    
    -- Filter line if filters are active
    local filter_parts = {}
    if state.filter.tag then
        table.insert(filter_parts, "Tag: " .. ui.symbols.tag .. state.filter.tag)
    end
    if state.filter.project then
        table.insert(filter_parts, "Project: " .. ui.symbols.project .. state.filter.project)
    end
    if state.filter.search then
        table.insert(filter_parts, "Search: '" .. state.filter.search .. "'")
    end
    
    if #filter_parts > 0 then
        table.insert(lines, "Filters: " .. table.concat(filter_parts, " | "))
    end
    
    -- Separator
    table.insert(lines, string.rep("─", config.get().ui.width))
    
    -- Content based on section
    if state.section == "active" or state.section == "completed" then
        if #state.todos == 0 then
            table.insert(lines, "No todos found.")
        else
            for i, todo in ipairs(state.todos) do
                local checkbox = state.section == "completed" and ui.symbols.checkbox_checked or ui.symbols.checkbox_empty
                local priority_symbol = ui.symbols.priority[todo.priority or 0]
                
                -- Format todo line
                local line = checkbox .. " " .. priority_symbol
                if priority_symbol ~= "" then
                    line = line .. " "
                end
                
                line = line .. todo.content
                
                -- Add line with todo
                table.insert(lines, line)
                
                -- Highlight checkbox
                local checkbox_color = state.section == "completed" and ui.colors.checkbox_checked or ui.colors.checkbox
                table.insert(highlights, {
                    line = #lines - 1, 
                    col_start = 0, 
                    col_end = #checkbox, 
                    group = checkbox_color
                })
                
                -- Highlight priority
                if priority_symbol ~= "" then
                    table.insert(highlights, {
                        line = #lines - 1, 
                        col_start = #checkbox + 1, 
                        col_end = #checkbox + 1 + #priority_symbol, 
                        group = ui.colors.priority[todo.priority or 0]
                    })
                end
                
                -- Metadata line: due date, tags, project
                local metadata = {}
                
                if todo.due_date and todo.due_date ~= "" then
                    local rel_date = utils.format_relative_date(todo.due_date)
                    local date_text = ui.symbols.due .. " " .. todo.due_date .. " (" .. rel_date .. ")"
                    table.insert(metadata, date_text)
                    
                    -- Determine due date color
                    local due_color = ui.colors.due
                    if utils.is_past_due(todo.due_date) then
                        due_color = ui.colors.overdue
                    elseif utils.is_due_soon(todo.due_date) then
                        due_color = ui.colors.due_soon
                    end
                    
                    -- Add date highlight for next line
                    table.insert(highlights, {
                        line = #lines, 
                        col_start = 2, 
                        col_end = 2 + #date_text, 
                        group = due_color
                    })
                end
                
                -- Tags
                local tags = todo.tags or {}
                if type(tags) == "string" then
                    tags = vim.split(tags, ",")
                end
                
                if #tags > 0 then
                    local tags_text = ""
                    for _, tag in ipairs(tags) do
                        tags_text = tags_text .. ui.symbols.tag .. tag .. " "
                    end
                    
                    if tags_text ~= "" then
                        table.insert(metadata, tags_text:sub(1, -2))  -- Remove trailing space
                        
                        -- Add tags highlight for next line
                        table.insert(highlights, {
                            line = #lines, 
                            col_start = metadata[1] and #metadata[1] + 5 or 2, 
                            col_end = metadata[1] and #metadata[1] + 5 + #tags_text or 2 + #tags_text, 
                            group = ui.colors.tag
                        })
                    end
                end
                
                -- Project
                if todo.project and todo.project ~= "" then
                    local project_text = ui.symbols.project .. todo.project
                    table.insert(metadata, project_text)
                    
                    -- Add project highlight for next line
                    local col_start = 2
                    if #metadata > 1 then
                        col_start = 5 + #table.concat(metadata, " | ", 1, #metadata-1)
                    end
                    
                    table.insert(highlights, {
                        line = #lines, 
                        col_start = col_start, 
                        col_end = col_start + #project_text, 
                        group = ui.colors.project
                    })
                end
                
                -- Add metadata line if exists
                if #metadata > 0 then
                    table.insert(lines, "  " .. table.concat(metadata, " | "))
                end
                
                -- Add empty line after each todo
                table.insert(lines, "")
            end
        end
    elseif state.section == "stats" then
        -- Statistics section
        local stats_data = db.calculate_statistics()
        
        table.insert(lines, ui.symbols.stats .. " TODO STATISTICS")
        table.insert(highlights, {
            line = #lines - 1, 
            col_start = 0, 
            col_end = #lines[#lines], 
            group = ui.colors.stats
        })
        
        table.insert(lines, "")
        table.insert(lines, "General:")
        table.insert(lines, "  • Total todos: " .. stats_data.total)
        table.insert(lines, "  • Active: " .. stats_data.active .. " (" .. stats_data.active_percent .. "%)")
        table.insert(lines, "  • Completed: " .. stats_data.completed .. " (" .. stats_data.completion_rate .. "%)")
        table.insert(lines, "")
        
        table.insert(lines, "Recents:")
        table.insert(lines, "  • Added today: " .. stats_data.added_today)
        table.insert(lines, "  • Completed today: " .. stats_data.completed_today)
        table.insert(lines, "  • Completed this week: " .. stats_data.completed_this_week)
        table.insert(lines, "")
        
        if stats_data.avg_completion_time then
            table.insert(lines, "Performance:")
            table.insert(lines, "  • Average completion time: " .. stats_data.avg_completion_time .. " days")
            table.insert(lines, "")
        end
        
        -- Tag statistics
        if stats_data.tags and #stats_data.tags > 0 then
            table.insert(lines, "Top Tags:")
            for i, tag_data in ipairs(stats_data.tags) do
                if i <= 5 then  -- Only show top 5
                    table.insert(lines, "  • " .. ui.symbols.tag .. tag_data.tag .. ": " .. tag_data.count)
                    
                    -- Highlight tag
                    table.insert(highlights, {
                        line = #lines - 1, 
                        col_start = 4, 
                        col_end = 5 + #tag_data.tag, 
                        group = ui.colors.tag
                    })
                end
            end
            table.insert(lines, "")
        end
        
        -- Project statistics
        if stats_data.projects and #stats_data.projects > 0 then
            table.insert(lines, "Top Projects:")
            for i, project_data in ipairs(stats_data.projects) do
                if i <= 5 then  -- Only show top 5
                    table.insert(lines, "  • " .. ui.symbols.project .. project_data.project .. ": " .. project_data.count)
                    
                    -- Highlight project
                    table.insert(highlights, {
                        line = #lines - 1, 
                        col_start = 4, 
                        col_end = 5 + #project_data.project, 
                        group = ui.colors.project
                    })
                end
            end
            table.insert(lines, "")
        end
    end
    
    -- Add help if enabled
    if state.show_help then
        table.insert(lines, "KEYBOARD SHORTCUTS")
        table.insert(highlights, {
            line = #lines - 1, 
            col_start = 0, 
            col_end = 18, 
            group = ui.colors.title
        })
        
        local help_items = {
            {"j/k", "Navigate up/down"},
            {"1", "Switch to active todos"},
            {"2", "Switch to completed todos"},
            {"3", "Switch to statistics view"},
            {"a", "Add new todo"},
            {"c", "Complete selected todo"},
            {"d", "Delete selected todo"},
            {"e", "Edit selected todo"},
            {"t", "Filter by tag"},
            {"p", "Filter by project"},
            {"s", "Search todos"},
            {"r", "Refresh data"},
            {"q", "Close window"},
            {"?", "Toggle help"}
        }
        
        for _, item in ipairs(help_items) do
            local key = item[1]
            local desc = item[2]
            table.insert(lines, "  " .. key .. " - " .. desc)
            
            -- Highlight key
            table.insert(highlights, {
                line = #lines - 1, 
                col_start = 2, 
                col_end = 2 + #key, 
                group = ui.colors.help
            })
        end
    end
    
    -- Set lines
    vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
    
    -- Apply highlights
    for _, hl in ipairs(highlights) do
        vim.api.nvim_buf_add_highlight(
            state.buf, 
            -1, 
            hl.group, 
            hl.line, 
            hl.col_start, 
            hl.col_end
        )
    end
    
    vim.api.nvim_buf_set_option(state.buf, "modifiable", false)
end

-- Load todos from database
local function load_todos()
    local options = {}
    
    if state.section == "active" then
        options.completed = false
    elseif state.section == "completed" then
        options.completed = true
    end
    
    if state.filter.tag then
        options.tag = state.filter.tag
    end
    
    if state.filter.project then
        options.project = state.filter.project
    end
    
    if state.filter.search then
        options.search = state.filter.search
    end
    
    state.todos = db.get_todos(options)
    state.selected_idx = math.min(state.selected_idx, #state.todos)
    if state.selected_idx < 1 and #state.todos > 0 then
        state.selected_idx = 1
    end
end

-- Load metadata from database
local function load_metadata()
    local metadata = db.get_metadata()
    state.metadata.tags = metadata.tags or {}
    state.metadata.projects = metadata.projects or {}
end

-- Setup keymaps in the todo buffer
local function setup_keymaps()
    if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
        return
    end
    
    local function map(key, callback)
        vim.api.nvim_buf_set_keymap(state.buf, 'n', key, '', {
            noremap = true,
            silent = true,
            callback = callback
        })
    end
    
    -- Navigation
    map('j', function()
        if #state.todos == 0 then return end
        state.selected_idx = math.min(state.selected_idx + 1, #state.todos)
        vim.api.nvim_win_set_cursor(state.win, {3 + (state.selected_idx - 1) * 3, 0})
    end)
    
    map('k', function()
        if #state.todos == 0 then return end
        state.selected_idx = math.max(state.selected_idx - 1, 1)
        vim.api.nvim_win_set_cursor(state.win, {3 + (state.selected_idx - 1) * 3, 0})
    end)
    
    -- Sections
    map('1', function()
        state.section = "active"
        state.selected_idx = 1
        load_todos()
        render()
    end)
    
    map('2', function()
        state.section = "completed"
        state.selected_idx = 1
        load_todos()
        render()
    end)
    
    map('3', function()
        state.section = "stats"
        state.selected_idx = 1
        render()
    end)
    
    -- CRUD operations
    map('a', function()
        vim.ui.input({prompt = "New Todo: "}, function(input)
            if input and input ~= "" then
                local todo_info = utils.parse_todo(input)
                local success = db.add_todo(input, {
                    priority = todo_info.priority,
                    due_date = todo_info.due_date,
                    project = todo_info.project,
                    tags = todo_info.tags
                })
                
                if success then
                    vim.notify("Todo added: " .. input, vim.log.levels.INFO)
                    load_todos()
                    load_metadata()
                    render()
                else
                    vim.notify("Failed to add todo", vim.log.levels.ERROR)
                end
            end
        end)
    end)
    
    map('c', function()
        if state.section ~= "active" or #state.todos == 0 then return end
        
        local todo = state.todos[state.selected_idx]
        if todo then
            local success = db.complete_todo(todo.id)
            if success then
                vim.notify("Todo completed: " .. todo.content, vim.log.levels.INFO)
                load_todos()
                render()
            else
                vim.notify("Failed to complete todo", vim.log.levels.ERROR)
            end
        end
    end)
    
    map('d', function()
        if #state.todos == 0 then return end
        
        local todo = state.todos[state.selected_idx]
        if todo then
            vim.ui.input({
                prompt = "Delete todo: " .. todo.content .. "? (y/N): ",
            }, function(input)
                if input and input:lower() == "y" then
                    local success = db.delete_todo(todo.id)
                    if success then
                        vim.notify("Todo deleted", vim.log.levels.INFO)
                        load_todos()
                        render()
                    else
                        vim.notify("Failed to delete todo", vim.log.levels.ERROR)
                    end
                end
            end)
        end
    end)
    
    map('e', function()
        if #state.todos == 0 then return end
        
        local todo = state.todos[state.selected_idx]
        if todo then
            vim.ui.input({
                prompt = "Edit todo: ",
                default = todo.content
            }, function(input)
                if input and input ~= "" then
                    local todo_info = utils.parse_todo(input)
                    local success = db.update_todo(todo.id, {
                        content = input,
                        priority = todo_info.priority,
                        due_date = todo_info.due_date,
                        project = todo_info.project,
                        tags = todo_info.tags
                    })
                    
                    if success then
                        vim.notify("Todo updated", vim.log.levels.INFO)
                        load_todos()
                        load_metadata()
                        render()
                    else
                        vim.notify("Failed to update todo", vim.log.levels.ERROR)
                    end
                end
            end)
        end
    end)
    
    -- Filtering
    map('t', function()
        if #state.metadata.tags == 0 then
            vim.notify("No tags found", vim.log.levels.INFO)
            return
        end
        
        -- Build selection menu
        local items = {"Clear filter"}
        for _, tag in ipairs(state.metadata.tags) do
            table.insert(items, ui.symbols.tag .. tag)
        end
        
        vim.ui.select(items, {
            prompt = "Filter by tag:",
        }, function(choice, idx)
            if idx == 1 then
                state.filter.tag = nil
            elseif choice then
                state.filter.tag = choice:sub(2)  -- Remove the # symbol
            end
            load_todos()
            render()
        end)
    end)
    
    map('p', function()
        if #state.metadata.projects == 0 then
            vim.notify("No projects found", vim.log.levels.INFO)
            return
        end
        
        -- Build selection menu
        local items = {"Clear filter"}
        for _, project in ipairs(state.metadata.projects) do
            table.insert(items, ui.symbols.project .. project)
        end
        
        vim.ui.select(items, {
            prompt = "Filter by project:",
        }, function(choice, idx)
            if idx == 1 then
                state.filter.project = nil
            elseif choice then
                state.filter.project = choice:sub(2)  -- Remove the @ symbol
            end
            load_todos()
            render()
        end)
    end)
    
    map('s', function()
        vim.ui.input({
            prompt = "Search todos: ",
        }, function(input)
            if input then
                if input == "" then
                    state.filter.search = nil
                else
                    state.filter.search = input
                end
                load_todos()
                render()
            end
        end)
    end)
    
    -- Other actions
    map('r', function()
        load_todos()
        load_metadata()
        render()
    end)
    
    map('?', function()
        state.show_help = not state.show_help
        render()
    end)
    
    map('q', function()
        if state.win and vim.api.nvim_win_is_valid(state.win) then
            vim.api.nvim_win_close(state.win, true)
        end
    end)
    
    -- Close on Escape
    map('<Esc>', function()
        if state.win and vim.api.nvim_win_is_valid(state.win) then
            vim.api.nvim_win_close(state.win, true)
        end
    end)
end

-- Public API

-- Open Todo UI
function M.open(options)
    -- Set default options
    options = options or {}
    
    -- Initialize highlights
    setup_highlights()
    
    -- Create window and buffer
    create_float_win()
    
    -- Reset state
    state.section = options.section or "active"
    state.selected_idx = 1
    state.filter = {
        tag = options.tag,
        project = options.project,
        search = options.search
    }
    
    -- Load data
    load_todos()
    load_metadata()
    
    -- Setup keymaps
    setup_keymaps()
    
    -- Render UI
    render()
end

-- Add a todo with a prompt
function M.add_todo()
    vim.ui.input({prompt = "New Todo: "}, function(input)
        if input and input ~= "" then
            local todo_info = utils.parse_todo(input)
            local success = db.add_todo(input, {
                priority = todo_info.priority,
                due_date = todo_info.due_date,
                project = todo_info.project,
                tags = todo_info.tags
            })
            
            if success then
                vim.notify("Todo added: " .. input, vim.log.levels.INFO)
            else
                vim.notify("Failed to add todo", vim.log.levels.ERROR)
            end
        end
    end)
end

-- Complete a todo with a prompt
function M.complete_todo_with_prompt()
    local todos = db.get_todos({completed = false})
    
    if #todos == 0 then
        vim.notify("No active todos found", vim.log.levels.INFO)
        return
    end
    
    local items = {}
    for _, todo in ipairs(todos) do
        table.insert(items, todo.id .. ": " .. todo.content)
    end
    
    vim.ui.select(items, {
        prompt = "Select todo to complete:",
    }, function(choice)
        if not choice then return end
        
        local todo_id = tonumber(choice:match("^(%d+):"))
        if todo_id then
            local success = db.complete_todo(todo_id)
            if success then
                vim.notify("Todo completed", vim.log.levels.INFO)
            else
                vim.notify("Failed to complete todo", vim.log.levels.ERROR)
            end
        end
    end)
end

-- Open active todos
function M.open_todos()
    M.open({section = "active"})
end

-- Open completed todos
function M.open_completed_todos()
    M.open({section = "completed"})
end

-- Open statistics view
function M.open_stats()
    M.open({section = "stats"})
end

return M 