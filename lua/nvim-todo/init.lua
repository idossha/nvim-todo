-- Main plugin initialization
local core = require('nvim-todo.core')
local ui = require('nvim-todo.ui')

-- Create commands when the plugin is loaded
local function create_commands()
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
local function create_keymaps()
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

-- Custom setup function
local function setup(opts)
    -- Initialize core functionality
    core.setup(opts)
    
    -- Create commands and keymaps
    create_commands()
    create_keymaps()
end

-- Return public API
return {
    setup = setup,
    add_todo = core.add_todo,
    complete_todo = core.complete_todo,
    open_todos = core.open_todos,
    open_completed_todos = core.open_completed_todos,
    open_statistics = core.open_statistics,
    find_todo_files = core.find_todo_files,
    live_grep_todos = core.live_grep_todos,
    debug_config = core.debug_config,
    
    -- Database-specific functions
    migrate_to_database = core.migrate_to_database,
    export_database_to_files = core.export_database_to_files,
    toggle_view_mode = core.toggle_view_mode,
    search_todos = core.search_todos
}
