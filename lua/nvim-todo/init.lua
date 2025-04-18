-- Main plugin initialization
local M = {}

-- Setup function to be called by user
function M.setup(opts)
    -- Load config first
    local config = require('nvim-todo.config')
    config.setup(opts)
    
    -- Then load other modules
    local db = require('nvim-todo.db')
    local ui = require('nvim-todo.ui')
    local core = require('nvim-todo.core')
    
    -- Initialize database
    if not db.setup() then
        vim.notify("Failed to initialize database", vim.log.levels.ERROR)
        return false
    end
    
    -- Create commands
    create_commands(core, ui)
    
    -- Set up keymaps
    create_keymaps(config)
    
    return true
end

-- Create commands when the plugin is loaded
local function create_commands(core, ui)
    -- Create user commands
    vim.api.nvim_create_user_command('TodoAdd', function(args)
        core.add_todo(table.concat(args.fargs, " "))
    end, { nargs = '+', desc = 'Add a new todo item' })
    
    vim.api.nvim_create_user_command('TodoComplete', function()
        ui.complete_todo_with_prompt()
    end, { desc = 'Mark a todo item as complete' })
    
    vim.api.nvim_create_user_command('TodoList', core.open_todos, {
        desc = 'Open active todo list'
    })
    
    vim.api.nvim_create_user_command('TodoCompletedList', core.open_completed_todos, {
        desc = 'Open completed todo list'
    })
    
    vim.api.nvim_create_user_command('TodoStats', core.open_statistics, {
        desc = 'Open todo statistics'
    })
    
    vim.api.nvim_create_user_command('TodoFindFiles', core.find_todo_files, {
        desc = 'Find files in todo directory'
    })
    
    vim.api.nvim_create_user_command('TodoLiveGrep', core.live_grep_todos, {
        desc = 'Live grep in todo directory'
    })
    
    vim.api.nvim_create_user_command('TodoMigrateToDb', core.migrate_to_database, {
        desc = 'Migrate todos from files to database'
    })
    
    vim.api.nvim_create_user_command('TodoExportToFiles', core.export_database_to_files, {
        desc = 'Export todos from database to files'
    })
    
    vim.api.nvim_create_user_command('TodoToggleViewMode', core.toggle_view_mode, {
        desc = 'Toggle between database and file view mode'
    })
    
    vim.api.nvim_create_user_command('TodoSearch', function(args)
        if args.fargs and #args.fargs > 0 then
            local search_term = table.concat(args.fargs, " ")
            core.search_todos(search_term)
        else
            ui.search_todos()
        end
    end, { nargs = '*', desc = 'Search todos by content' })
    
    vim.api.nvim_create_user_command('TodoDebug', core.debug_config, {
        desc = 'Show debug information about todo plugin'
    })
end

-- Set up default keymappings
local function create_keymaps(config)
    -- Set up keymappings
    vim.api.nvim_set_keymap('n', '<leader>ta', ':TodoAdd ', 
        { noremap = true, silent = false, desc = 'Add Todo' })
    vim.api.nvim_set_keymap('n', '<leader>tc', ':TodoComplete<CR>', 
        { noremap = true, silent = true, desc = 'Complete Todo' })
    vim.api.nvim_set_keymap('n', '<leader>to', ':TodoList<CR>', 
        { noremap = true, silent = true, desc = 'List Todos' })
    vim.api.nvim_set_keymap('n', '<leader>th', ':TodoCompletedList<CR>', 
        { noremap = true, silent = true, desc = 'List Completed Todos' })
    vim.api.nvim_set_keymap('n', '<leader>ts', ':TodoStats<CR>', 
        { noremap = true, silent = true, desc = 'Todo Statistics' })
    vim.api.nvim_set_keymap('n', '<leader>tf', ':TodoFindFiles<CR>', 
        { noremap = true, silent = true, desc = 'Find Todo Files' })
    vim.api.nvim_set_keymap('n', '<leader>tg', ':TodoLiveGrep<CR>', 
        { noremap = true, silent = true, desc = 'Live Grep Todos' })
    vim.api.nvim_set_keymap('n', '<leader>ts', ':TodoSearch<CR>', 
        { noremap = true, silent = true, desc = 'Search Todos' })
end

-- Export functions for the public API
function M.add_todo(...)
    return require('nvim-todo.core').add_todo(...)
end

function M.complete_todo(...)
    return require('nvim-todo.core').complete_todo(...)
end

function M.delete_todo(...)
    return require('nvim-todo.core').delete_todo(...)
end

function M.show_statistics(...)
    return require('nvim-todo.core').show_statistics(...)
end

function M.migrate_to_database(...)
    return require('nvim-todo.core').migrate_to_database(...)
end

function M.export_database_to_files(...)
    return require('nvim-todo.core').export_database_to_files(...)
end

function M.toggle_view_mode(...)
    return require('nvim-todo.core').toggle_view_mode(...)
end

function M.search_todos(...)
    return require('nvim-todo.core').search_todos(...)
end

function M.open_todo_ui(...)
    return require('nvim-todo.ui').open(...)
end

return M
