local M = {}
local utils = require('nvim-todo.utils')

-- Default configuration
local default_config = {
    -- Default path for todo files (legacy)
    todo_dir = vim.fn.expand("~/.local/share/nvim/nvim-todo/files"),
    -- Filenames for different todo types (legacy)
    active_todo_file = "todos.md",
    completed_todo_file = "completed_todos.md",
    statistics_file = "todo_stats.md",
    -- Use telescope if available
    use_telescope = pcall(require, 'telescope.builtin'),
    -- Database configuration
    use_database = true,
    db_path = vim.fn.expand("~/.local/share/nvim/nvim-todo/todo.db"),
    -- Migration settings
    auto_migrate = true,
    -- View mode (database or files)
    view_mode = "database"  -- "database" or "files"
}

-- Current configuration (initialized to defaults)
local config = vim.deepcopy(default_config)

-- State management (internal variables)
local state = {
    migration_complete = false,
    initialized = false
}

-- Setup the configuration with user options
function M.setup(opts)
    opts = opts or {}
    
    -- Merge user options with defaults
    for k, v in pairs(opts) do
        config[k] = v
    end
    
    -- Ensure directories exist
    if not utils.create_directory(config.todo_dir) then
        vim.notify("Failed to create todo directory", vim.log.levels.ERROR)
    end
    
    -- Ensure database directory exists if using database
    if config.use_database then
        local db_dir = vim.fn.fnamemodify(config.db_path, ":h")
        if not utils.create_directory(db_dir) then
            vim.notify("Failed to create database directory", vim.log.levels.ERROR)
        end
    end
    
    state.initialized = true
    return true
end

-- Get the current configuration
function M.get()
    return config
end

-- Get internal state
function M.get_state()
    return state
end

-- Update state values
function M.update_state(key, value)
    state[key] = value
end

-- Get a specific configuration value
function M.get_value(key)
    return config[key]
end

-- Set a specific configuration value
function M.set_value(key, value)
    config[key] = value
end

-- Get path for active todo file
function M.get_active_todo_path()
    return config.todo_dir .. "/" .. config.active_todo_file
end

-- Get path for completed todo file
function M.get_completed_todo_path()
    return config.todo_dir .. "/" .. config.completed_todo_file
end

-- Get path for statistics file
function M.get_statistics_path()
    return config.todo_dir .. "/" .. config.statistics_file
end

-- Print debug information about configuration
function M.debug_config()
    local debug_info = "Todo Plugin Configuration:\n"
    
    for k, v in pairs(config) do
        debug_info = debug_info .. string.format("- %s: %s\n", k, tostring(v))
    end
    
    debug_info = debug_info .. "\nInternal State:\n"
    for k, v in pairs(state) do
        debug_info = debug_info .. string.format("- %s: %s\n", k, tostring(v))
    end
    
    print(debug_info)
end

return M 