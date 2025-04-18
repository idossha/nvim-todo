local M = {}
local utils = require('todo.utils')

-- Default configuration
local default_config = {
    -- Database configuration
    db_path = vim.fn.expand("~/.local/share/nvim/todo.nvim/todo.db"),
    -- UI Settings
    ui = {
        width = 80,  -- Width of the floating window
        height = 25,  -- Height of the floating window
        border = "rounded",  -- Border style: "none", "single", "double", "rounded"
        icons = true,  -- Use icons in the UI
        mappings = {  -- Custom key mappings
            open = "<leader>to",
            add = "<leader>ta",
            global_add = "<leader>ta"
        }
    }
}

-- Current configuration (initialized to defaults)
local config = vim.deepcopy(default_config)

-- Setup the configuration with user options
function M.setup(opts)
    opts = opts or {}
    
    -- Merge user options with defaults
    for k, v in pairs(opts) do
        if k == "ui" and type(v) == "table" then
            -- Deep merge for UI options
            for ui_k, ui_v in pairs(v) do
                config.ui[ui_k] = ui_v
            end
        else
            config[k] = v
        end
    end
    
    -- Ensure database directory exists
    local db_dir = vim.fn.fnamemodify(config.db_path, ":h")
    if not utils.create_directory(db_dir) then
        vim.notify("Failed to create database directory", vim.log.levels.ERROR)
    end
    
    return true
end

-- Get the current configuration
function M.get()
    return config
end

-- Get a specific configuration value
function M.get_value(key)
    local keys = vim.split(key, ".", { plain = true })
    local current = config
    
    for _, k in ipairs(keys) do
        if type(current) ~= "table" then
            return nil
        end
        current = current[k]
    end
    
    return current
end

-- Set a specific configuration value
function M.set_value(key, value)
    local keys = vim.split(key, ".", { plain = true })
    local current = config
    
    for i = 1, #keys - 1 do
        local k = keys[i]
        if type(current[k]) ~= "table" then
            current[k] = {}
        end
        current = current[k]
    end
    
    current[keys[#keys]] = value
end

-- Print debug information about configuration
function M.debug_config()
    local debug_info = "Todo Plugin Configuration:\n"
    
    local function format_table(tbl, indent)
        indent = indent or 0
        local result = ""
        local indent_str = string.rep("  ", indent)
        
        for k, v in pairs(tbl) do
            if type(v) == "table" then
                result = result .. string.format("%s%s:\n", indent_str, k)
                result = result .. format_table(v, indent + 1)
            else
                result = result .. string.format("%s%s: %s\n", indent_str, k, tostring(v))
            end
        end
        
        return result
    end
    
    debug_info = debug_info .. format_table(config)
    
    print(debug_info)
end

return M 