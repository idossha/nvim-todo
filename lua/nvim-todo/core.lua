local M = {}

-- Import required modules
local config = require('nvim-todo.config')
local db = require('nvim-todo.db')
local files = require('nvim-todo.files')
local stats = require('nvim-todo.stats')
local ui = require('nvim-todo.ui')
local migration = require('nvim-todo.migration')
local utils = require('nvim-todo.utils')

-- Initialize the plugin with user config
function M.setup(opts)
    -- Setup configuration
    config.setup(opts)
    
    -- Initialize database
    if not db.setup() then
        vim.notify("Failed to initialize database", vim.log.levels.ERROR)
        return false
    end
    
    -- Create user commands
    M.create_commands()
    
    -- Set up keymaps
    M.create_keymaps()
    
    -- Check for migration if needed
    migration.check_and_migrate()
    
    return true
end

-- Create command mappings
function M.create_commands()
    -- Main UI commands
    vim.api.nvim_create_user_command('TodoOpen', function()
        ui.open()
    end, { desc = 'Open Todo manager UI' })
    
    -- Add todo directly from command line
    vim.api.nvim_create_user_command('TodoAdd', function(args)
        if args.args and args.args ~= "" then
            local todo_info = utils.parse_todo(args.args)
            
            local success = db.add_todo(args.args, {
                priority = todo_info.priority,
                due_date = todo_info.due_date,
                project = todo_info.project
            })
            
            if success then
                vim.notify("Todo added: " .. args.args, vim.log.levels.INFO)
            else
                vim.notify("Failed to add todo", vim.log.levels.ERROR)
            end
        else
            ui.add_todo()
        end
    end, { nargs = '*', desc = 'Add a new todo' })
    
    -- Complete a todo directly by ID
    vim.api.nvim_create_user_command('TodoComplete', function(args)
        if args.args and args.args ~= "" then
            local todo_id = tonumber(args.args)
            if todo_id then
                local success = db.complete_todo(todo_id)
                if success then
                    vim.notify("Todo " .. todo_id .. " completed", vim.log.levels.INFO)
                else
                    vim.notify("Failed to complete todo " .. todo_id, vim.log.levels.ERROR)
                end
            else
                vim.notify("Invalid todo ID", vim.log.levels.ERROR)
            end
        else
            -- Open UI to select a todo to complete
            ui.open()
        end
    end, { nargs = '?', desc = 'Complete a todo' })
    
    -- Show all overdue todos
    vim.api.nvim_create_user_command('TodoOverdue', function()
        local today = utils.get_today()
        ui.open({ due_before = today })
    end, { desc = 'Show overdue todos' })
    
    -- Show todos due today
    vim.api.nvim_create_user_command('TodoToday', function()
        local today = utils.get_today()
        ui.open({ due_today = today })
    end, { desc = 'Show todos due today' })
    
    -- Show statistics
    vim.api.nvim_create_user_command('TodoStats', function()
        ui.open_stats()
    end, { desc = 'Show todo statistics' })
    
    -- Debug command
    vim.api.nvim_create_user_command('TodoDebug', function()
        config.debug_config()
    end, { desc = 'Show debug information' })
end

-- Create keymappings
function M.create_keymaps()
    local key_config = config.get_value("ui.mappings")
    
    -- Global mapping to open todo UI
    vim.api.nvim_set_keymap('n', key_config.open, ':TodoOpen<CR>', 
        { noremap = true, silent = true, desc = 'Open Todo Manager' })
    
    -- Global mapping to quickly add a todo
    vim.api.nvim_set_keymap('n', key_config.add, ':TodoAdd ', 
        { noremap = true, silent = false, desc = 'Add a Todo' })
end

-- Open the Todo UI
function M.open_todo_ui()
    ui.open()
end

-- Add a new todo with options
function M.add_todo(content, options)
    if not content or content == "" then
        ui.add_todo()
        return
    end
    
    -- Parse todo text for metadata if not provided in options
    if not options then
        local todo_info = utils.parse_todo(content)
        options = {
            priority = todo_info.priority,
            due_date = todo_info.due_date,
            project = todo_info.project
        }
    end
    
    local success = db.add_todo(content, options)
    
    if success then
        vim.notify("Todo added: " .. content, vim.log.levels.INFO)
        return true
    else
        vim.notify("Failed to add todo", vim.log.levels.ERROR)
        return false
    end
end

-- Complete a todo by ID
function M.complete_todo(todo_id)
    local success = db.complete_todo(todo_id)
    
    if success then
        vim.notify("Todo completed", vim.log.levels.INFO)
        return true
    else
        vim.notify("Failed to complete todo", vim.log.levels.ERROR)
        return false
    end
end

-- Delete a todo by ID
function M.delete_todo(todo_id)
    local success = db.delete_todo(todo_id)
    
    if success then
        vim.notify("Todo deleted", vim.log.levels.INFO)
        return true
    else
        vim.notify("Failed to delete todo", vim.log.levels.ERROR)
        return false
    end
end

-- Open statistics view
function M.show_statistics()
    ui.open_stats()
end

-- Open the active todos
function M.open_todos()
    return ui.open_todos()
end

-- Open the completed todos
function M.open_completed_todos()
    return ui.open_completed_todos()
end

-- Open statistics view
function M.open_statistics()
    local config_values = config.get()
    
    if config_values.use_database and config_values.view_mode == "database" then
        -- Get statistics from database
        local stats_data = db.calculate_statistics()
        
        -- Create a temporary stats file
        local stats_path = config.get_statistics_path()
        local stats_content = stats.format_statistics_content(stats_data)
        
        -- Write to file
        utils.write_to_file(stats_path, stats_content, "w")
        
        -- Open the file
        vim.cmd('edit ' .. stats_path)
    else
        -- Use file-based statistics
        stats.update_statistics_file()
        vim.cmd('edit ' .. config.get_statistics_path())
    end
end

-- Find todo files
function M.find_todo_files()
    return ui.find_todo_files()
end

-- Live grep in todo files
function M.live_grep_todos()
    return ui.live_grep_todos()
end

-- Toggle the view mode (database or files)
function M.toggle_view_mode()
    return migration.toggle_view_mode()
end

-- Search todos
function M.search_todos()
    return ui.search_todos()
end

-- Migrate from files to database
function M.migrate_to_database()
    local config_values = config.get()
    
    -- Only proceed if we're using the database
    if not config_values.use_database then
        vim.notify("Database mode is not enabled in configuration", vim.log.levels.WARN)
        return false
    end
    
    -- Perform the migration
    return migration.import_to_db(config_values.db_path)
end

-- Export from database to files
function M.export_database_to_files()
    local config_values = config.get()
    
    -- Only proceed if we're using the database
    if not config_values.use_database then
        vim.notify("Database mode is not enabled in configuration", vim.log.levels.WARN)
        return false
    end
    
    -- Perform the export
    return migration.export_from_db(config_values.db_path)
end

return M
