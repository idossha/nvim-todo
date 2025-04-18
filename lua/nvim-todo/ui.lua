local M = {}
local config = require('nvim-todo.config')
local db_module = require('nvim-todo.db')
local files_module = require('nvim-todo.files')
local utils = require('nvim-todo.utils')

-- Check if telescope is available
local has_telescope, telescope = pcall(require, 'telescope.builtin')

-- Format todos for display
local function format_todos_for_display(todos, show_completed)
    local formatted = {}
    
    for _, todo in ipairs(todos) do
        local status_symbol = todo.status == "active" and "[ ]" or "[x]"
        local display_string = string.format("%s %s", status_symbol, todo.content)
        
        -- Add creation timestamp
        if todo.created_at then
            display_string = display_string .. string.format(" (Created: %s)", todo.created_at)
        end
        
        -- Add completion timestamp for completed todos
        if show_completed and todo.completed_at then
            display_string = display_string .. string.format(" (Completed: %s)", todo.completed_at)
        end
        
        table.insert(formatted, {
            id = todo.id,
            display = display_string,
            content = todo.content,
            status = todo.status
        })
    end
    
    return formatted
end

-- Open the active todos file or show active todos from database
function M.open_todos()
    local config_values = config.get()
    
    if config_values.use_database and config_values.view_mode == "database" then
        -- Get todos from database
        local todos = db_module.get_active_todos()
        
        -- Format for display
        local formatted_todos = format_todos_for_display(todos, false)
        
        -- Create a temporary file for viewing
        local temp_file_path = config.get_active_todo_path()
        local file_content = "# Active Todos\n\n"
        
        for _, todo in ipairs(formatted_todos) do
            file_content = file_content .. todo.display .. "\n"
        end
        
        -- Write to temp file
        utils.write_to_file(temp_file_path, file_content, "w")
        
        -- Open the file
        vim.cmd('edit ' .. temp_file_path)
        
        -- Set buffer local mappings for database operations
        vim.cmd([[
            augroup nvim_todo_buffer_mappings
            autocmd!
            autocmd BufEnter ]] .. temp_file_path .. [[ lua require('nvim-todo.ui').setup_buffer_mappings()
            augroup END
        ]])
    else
        -- Ensure files exist
        files_module.ensure_todo_files()
        
        -- Open the active todo file
        vim.cmd('edit ' .. config.get_active_todo_path())
        
        -- Setup buffer mappings
        M.setup_buffer_mappings()
    end
end

-- Open the completed todos file or show completed todos from database
function M.open_completed_todos()
    local config_values = config.get()
    
    if config_values.use_database and config_values.view_mode == "database" then
        -- Get todos from database
        local todos = db_module.get_completed_todos()
        
        -- Format for display
        local formatted_todos = format_todos_for_display(todos, true)
        
        -- Create a temporary file for viewing
        local temp_file_path = config.get_completed_todo_path()
        local file_content = "# Completed Todos\n\n"
        
        for _, todo in ipairs(formatted_todos) do
            file_content = file_content .. todo.display .. "\n"
        end
        
        -- Write to temp file
        utils.write_to_file(temp_file_path, file_content, "w")
        
        -- Open the file
        vim.cmd('edit ' .. temp_file_path)
    else
        -- Ensure files exist
        files_module.ensure_todo_files()
        
        -- Open the completed todo file
        vim.cmd('edit ' .. config.get_completed_todo_path())
    end
end

-- Add a todo with a prompt
function M.add_todo_with_prompt()
    local config_values = config.get()
    
    -- Prompt user for todo content
    vim.ui.input({
        prompt = "New Todo: ",
    }, function(input)
        if input and input ~= "" then
            if config_values.use_database and config_values.view_mode == "database" then
                db_module.add_todo(input)
                
                -- Refresh the view if the todo file is open
                local bufnr = vim.fn.bufnr(config.get_active_todo_path())
                if bufnr ~= -1 then
                    M.open_todos()
                end
            else
                files_module.add_todo(input)
            end
        end
    end)
end

-- Complete a todo with prompt for ID or line number
function M.complete_todo_with_prompt()
    local config_values = config.get()
    
    if config_values.use_database and config_values.view_mode == "database" then
        -- Get active todos
        local todos = db_module.get_active_todos()
        local formatted_todos = format_todos_for_display(todos, false)
        
        -- Show a selection menu
        vim.ui.select(formatted_todos, {
            prompt = "Select a todo to complete:",
            format_item = function(item)
                return item.display
            end
        }, function(choice)
            if choice and choice.id then
                -- Complete the todo
                local success = db_module.complete_todo(choice.id)
                if success then
                    vim.notify("Todo completed: " .. choice.content, vim.log.levels.INFO)
                    
                    -- Refresh the view if the todo file is open
                    local bufnr = vim.fn.bufnr(config.get_active_todo_path())
                    if bufnr ~= -1 then
                        M.open_todos()
                    end
                else
                    vim.notify("Failed to complete todo", vim.log.levels.ERROR)
                end
            end
        end)
    else
        -- Get current buffer and line
        local bufnr = vim.api.nvim_get_current_buf()
        local active_path = config.get_active_todo_path()
        
        -- If current buffer is the active todo file
        if vim.api.nvim_buf_get_name(bufnr) == vim.fn.fnamemodify(active_path, ":p") then
            local line_nr = vim.api.nvim_win_get_cursor(0)[1]
            files_module.complete_todo_by_line(line_nr)
        else
            -- Otherwise, get line number from prompt
            vim.ui.input({
                prompt = "Enter line number to complete: ",
            }, function(input)
                if input and tonumber(input) then
                    files_module.complete_todo_by_line(tonumber(input))
                end
            end)
        end
    end
end

-- Set up buffer mappings for todo operations
function M.setup_buffer_mappings()
    local bufnr = vim.api.nvim_get_current_buf()
    
    -- Add keymappings for the current buffer
    vim.api.nvim_buf_set_keymap(bufnr, 'n', '<leader>ta', [[<cmd>lua require('nvim-todo.ui').add_todo_with_prompt()<CR>]], { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(bufnr, 'n', '<leader>tc', [[<cmd>lua require('nvim-todo.ui').complete_todo_with_prompt()<CR>]], { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(bufnr, 'n', '<leader>to', [[<cmd>lua require('nvim-todo.ui').open_todos()<CR>]], { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(bufnr, 'n', '<leader>th', [[<cmd>lua require('nvim-todo.ui').open_completed_todos()<CR>]], { noremap = true, silent = true })
end

-- Search todos with optional telescope integration
function M.search_todos()
    local config_values = config.get()
    
    if has_telescope and config_values.use_telescope then
        -- Use telescope for search
        local function show_todos_in_telescope(results)
            local pickers = require("telescope.pickers")
            local finders = require("telescope.finders")
            local conf = require("telescope.config").values
            local actions = require("telescope.actions")
            local action_state = require("telescope.actions.state")
            
            -- Create a picker
            pickers.new({}, {
                prompt_title = "Todos",
                finder = finders.new_table({
                    results = results,
                    entry_maker = function(entry)
                        return {
                            value = entry,
                            display = entry.display,
                            ordinal = entry.content,
                            id = entry.id,
                            status = entry.status
                        }
                    end
                }),
                sorter = conf.generic_sorter({}),
                attach_mappings = function(prompt_bufnr, map)
                    -- Add action to complete a todo
                    map('i', '<C-c>', function()
                        local selection = action_state.get_selected_entry()
                        actions.close(prompt_bufnr)
                        
                        -- Only allow completing active todos
                        if selection.value.status == "active" then
                            db_module.complete_todo(selection.value.id)
                            vim.notify("Todo completed: " .. selection.value.content, vim.log.levels.INFO)
                        else
                            vim.notify("This todo is already completed", vim.log.levels.WARN)
                        end
                    end)
                    
                    return true
                end,
            }):find()
        end
        
        -- Prompt for search term
        vim.ui.input({
            prompt = "Search todos: ",
        }, function(input)
            if input and input ~= "" then
                local results
                
                if config_values.use_database and config_values.view_mode == "database" then
                    -- Search in database
                    local todos = db_module.search_todos(input)
                    results = format_todos_for_display(todos, true)
                else
                    -- Search in files
                    local todos = files_module.search_todos(input)
                    results = format_todos_for_display(todos, true)
                end
                
                if #results > 0 then
                    show_todos_in_telescope(results)
                else
                    vim.notify("No todos found for: " .. input, vim.log.levels.INFO)
                end
            end
        end)
    else
        -- Use built-in search without telescope
        vim.ui.input({
            prompt = "Search todos: ",
        }, function(input)
            if input and input ~= "" then
                local results
                
                if config_values.use_database and config_values.view_mode == "database" then
                    -- Search in database
                    results = db_module.search_todos(input)
                else
                    -- Search in files
                    results = files_module.search_todos(input)
                end
                
                -- Display results in a buffer
                if #results > 0 then
                    local buf = vim.api.nvim_create_buf(false, true)
                    vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
                    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
                    vim.api.nvim_buf_set_option(buf, 'filetype', 'markdown')
                    
                    local lines = { "# Search Results for: " .. input, "" }
                    
                    for _, todo in ipairs(results) do
                        local status_symbol = todo.status == "active" and "[ ]" or "[x]"
                        local line = string.format("%s %s", status_symbol, todo.content)
                        if todo.created_at then
                            line = line .. string.format(" (Created: %s)", todo.created_at)
                        end
                        if todo.completed_at then
                            line = line .. string.format(" (Completed: %s)", todo.completed_at)
                        end
                        table.insert(lines, line)
                    end
                    
                    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
                    vim.api.nvim_command('vsplit')
                    vim.api.nvim_win_set_buf(0, buf)
                else
                    vim.notify("No todos found for: " .. input, vim.log.levels.INFO)
                end
            end
        end)
    end
end

-- Find todo files using telescope
function M.find_todo_files()
    if has_telescope then
        local config_values = config.get()
        local todo_dir = config_values.todo_dir
        
        telescope.find_files({
            prompt_title = "Todo Files",
            cwd = todo_dir,
        })
    else
        vim.notify("Telescope not available", vim.log.levels.WARN)
    end
end

-- Live grep in todo files using telescope
function M.live_grep_todos()
    if has_telescope then
        local config_values = config.get()
        local todo_dir = config_values.todo_dir
        
        telescope.live_grep({
            prompt_title = "Search Todos",
            cwd = todo_dir,
        })
    else
        vim.notify("Telescope not available", vim.log.levels.WARN)
    end
end

return M 