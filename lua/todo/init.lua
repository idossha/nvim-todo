local M = {}

-- Default configuration
local default_config = require("todo.config").defaults

-- Plugin setup function
function M.setup(user_config)
    -- Merge user config with defaults
    M.config = vim.tbl_deep_extend("force", default_config, user_config or {})
    
    -- Ensure database directory exists
    local db_dir = vim.fn.fnamemodify(M.config.db_path, ":h")
    if vim.fn.isdirectory(db_dir) == 0 then
        vim.fn.mkdir(db_dir, "p")
    end
    
    -- Initialize the database
    require("todo.db").init(M.config.db_path)
    
    -- Register commands
    require("todo.commands").register()
end

-- Open the todo UI
function M.open()
    require("todo.ui").open()
end

-- Add a new todo
function M.add(text)
    if not text or text == "" then
        -- Open a prompt to add a new todo
        vim.ui.input({ prompt = "Todo: " }, function(input)
            if input and input ~= "" then
                require("todo.db").add_todo(input)
                vim.notify("Todo added", vim.log.levels.INFO)
            end
        end)
    else
        require("todo.db").add_todo(text)
        vim.notify("Todo added", vim.log.levels.INFO)
    end
end

-- Complete a todo
function M.complete(id)
    if not id then
        vim.notify("Todo ID required", vim.log.levels.ERROR)
        return
    end
    
    require("todo.db").complete_todo(id)
    vim.notify("Todo completed", vim.log.levels.INFO)
end

-- Show statistics
function M.stats()
    require("todo.ui").show_stats()
end

-- Show overdue todos
function M.overdue()
    require("todo.ui").show_overdue()
end

-- Show todos due today
function M.today()
    require("todo.ui").show_today()
end

return M
