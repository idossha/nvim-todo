local M = {}

-- Import required modules
local config = require('nvim-todo.config')
local db = require('nvim-todo.db')
local files = require('nvim-todo.files')
local stats = require('nvim-todo.stats')
local ui = require('nvim-todo.ui')
local migration = require('nvim-todo.migration')

-- Initialize the plugin with user config
function M.setup(opts)
    -- Setup configuration
    config.setup(opts)
    
    -- Initialize database if using it
    if config.get_value("use_database") then
        db.setup()
    end
    
    -- Check for migration if needed
    migration.check_and_migrate()
    
    -- Return success
    return true
end

-- Add a new todo
function M.add_todo(todo_text)
    local config_values = config.get()
    
    if config_values.use_database and config_values.view_mode == "database" then
        -- Add todo using database
        local success = db.add_todo(todo_text)
        if success then
            vim.notify("Todo added: " .. todo_text, vim.log.levels.INFO)
        else
            vim.notify("Failed to add todo", vim.log.levels.ERROR)
        end
        return success
    else
        -- Add todo using files
        return files.add_todo(todo_text)
    end
end

-- Complete a todo
function M.complete_todo(todo_id)
    local config_values = config.get()
    
    if config_values.use_database and config_values.view_mode == "database" then
        -- Complete todo using database
        local success = db.complete_todo(todo_id)
        if success then
            vim.notify("Todo completed", vim.log.levels.INFO)
        else
            vim.notify("Failed to complete todo", vim.log.levels.ERROR)
        end
        return success
    else
        -- Complete todo using files (line number-based)
        return files.complete_todo_by_line(todo_id)
    end
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
        local utils = require('nvim-todo.utils')
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

-- Debug configuration
function M.debug_config()
    return config.debug_config()
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
