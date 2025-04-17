local M = {}

-- Plugin configuration with default values
M.config = {
    -- Default path for todo files
    todo_dir = vim.fn.expand("~/todo"),
    -- Default filename for active todos
    active_todo_file = "todos.md",
    -- Default filename for completed todos
    completed_todo_file = "completed_todos.md"
}

-- Internal state
local state = {
    todo_dir = nil,
    active_todo_file = nil,
    completed_todo_file = nil
}

-- Ensure todo directory and files exist
local function ensure_todo_files()
    -- Create todo directory if it doesn't exist
    if vim.fn.isdirectory(state.todo_dir) == 0 then
        vim.fn.mkdir(state.todo_dir, "p")
    end

    -- Create active todos file if it doesn't exist
    local active_path = state.todo_dir .. "/" .. state.active_todo_file
    if vim.fn.filereadable(active_path) == 0 then
        local file = io.open(active_path, "w")
        if file then
            file:write("# Active Todos\n")
            file:close()
        end
    end

    -- Create completed todos file if it doesn't exist
    local completed_path = state.todo_dir .. "/" .. state.completed_todo_file
    if vim.fn.filereadable(completed_path) == 0 then
        local file = io.open(completed_path, "w")
        if file then
            file:write("# Completed Todos\n")
            file:close()
        end
    end
end

-- Add a new todo item
function M.add_todo(todo_text)
    local active_path = state.todo_dir .. "/" .. state.active_todo_file
    
    -- Open file in append mode
    local file = io.open(active_path, "a")
    if file then
        -- Use a checkbox format for todo items
        file:write("- [ ] " .. todo_text .. "\n")
        file:close()
        
        -- Notify user
        vim.notify("Todo added: " .. todo_text, vim.log.levels.INFO)
    else
        vim.notify("Failed to add todo", vim.log.levels.ERROR)
    end
end

-- Complete a todo item
function M.complete_todo()
    local active_path = state.todo_dir .. "/" .. state.active_todo_file
    local completed_path = state.todo_dir .. "/" .. state.completed_todo_file
    
    -- Get current line
    local current_line = vim.fn.getline('.')
    
    -- Check if line is a todo item
    if current_line:match("^%- %[ %]") then
        -- Remove checkbox and mark as completed
        local todo_text = current_line:gsub("^%- %[ %] ", "")
        local completion_date = os.date("%Y-%m-%d %H:%M:%S")
        
        -- Append to completed todos
        local completed_file = io.open(completed_path, "a")
        if completed_file then
            completed_file:write("- [x] " .. todo_text .. " (Completed: " .. completion_date .. ")\n")
            completed_file:close()
        end
        
        -- Remove from active todos
        local lines = {}
        for line in io.open(active_path):lines() do
            if line ~= current_line then
                table.insert(lines, line)
            end
        end
        
        -- Write updated active todos
        local active_file = io.open(active_path, "w")
        if active_file then
            for _, line in ipairs(lines) do
                active_file:write(line .. "\n")
            end
            active_file:close()
        end
        
        vim.notify("Todo completed: " .. todo_text, vim.log.levels.INFO)
    else
        vim.notify("Current line is not a todo item", vim.log.levels.WARN)
    end
end

-- Open todo files
function M.open_todos()
    -- Open active todos file
    vim.cmd('edit ' .. state.todo_dir .. '/' .. state.active_todo_file)
end

function M.open_completed_todos()
    -- Open completed todos file
    vim.cmd('edit ' .. state.todo_dir .. '/' .. state.completed_todo_file)
end

-- Setup function for the plugin
function M.setup(opts)
    -- Merge user config with default config
    opts = opts or {}
    for k, v in pairs(opts) do
        M.config[k] = v
    end
    
    -- Set internal state
    state.todo_dir = M.config.todo_dir
    state.active_todo_file = M.config.active_todo_file
    state.completed_todo_file = M.config.completed_todo_file
    
    -- Ensure todo files exist
    ensure_todo_files()
    
    -- Create user commands
    vim.api.nvim_create_user_command('TodoAdd', function(args)
        M.add_todo(table.concat(args.fargs, " "))
    end, { nargs = '+', desc = 'Add a new todo item' })
    
    vim.api.nvim_create_user_command('TodoComplete', M.complete_todo, {
        desc = 'Mark current todo item as complete'
    })
    
    vim.api.nvim_create_user_command('TodoList', M.open_todos, {
        desc = 'Open active todo list'
    })
    
    vim.api.nvim_create_user_command('TodoCompletedList', M.open_completed_todos, {
        desc = 'Open completed todo list'
    })
end

return M
