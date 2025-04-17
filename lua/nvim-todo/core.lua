local M = {}

-- Sanitize path to remove trailing slashes
local function sanitize_path(path)
    -- Remove trailing slashes, but preserve root path
    return path:gsub("(.-)/*$", "%1")
end

-- Plugin configuration with default values
M.config = {
    -- Default path for todo files (absolute path)
    todo_dir = "/tmp/todo",
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

-- Ensure todo directory and files exist with proper initial content
local function ensure_todo_files()
    -- Create todo directory if it doesn't exist
    local mkdir_cmd = string.format("mkdir -p %q", state.todo_dir)
    os.execute(mkdir_cmd)

    -- Paths for todo files
    local active_path = state.todo_dir .. "/" .. state.active_todo_file
    local completed_path = state.todo_dir .. "/" .. state.completed_todo_file

    -- Function to create file with initial content if it doesn't exist
    local function create_file_if_not_exists(path, initial_content)
        local file = io.open(path, "a+")
        if file then
            file:close()
            
            -- Check if file is empty
            local stat = vim.loop.fs_stat(path)
            if stat and stat.size == 0 then
                file = io.open(path, "w")
                if file then
                    file:write(initial_content or "# Todos\n")
                    file:close()
                end
            end
        end
    end

    -- Create files with initial content
    create_file_if_not_exists(active_path)
    create_file_if_not_exists(completed_path)
end

-- Write content to a file, ensuring file exists and is writable
local function write_to_file(path, content, mode)
    mode = mode or "a"
    local file = io.open(path, mode)
    if file then
        file:write(content)
        file:close()
        return true
    end
    return false
end

-- Read entire file contents
local function read_file(path)
    local file = io.open(path, "r")
    if file then
        local content = file:read("*all")
        file:close()
        return content
    end
    return nil
end

-- Add a new todo item
function M.add_todo(todo_text)
    local active_path = state.todo_dir .. "/" .. state.active_todo_file
    
    -- Prepare todo item
    local todo_item = "- [ ] " .. todo_text .. "\n"
    
    -- Append to file
    local success = write_to_file(active_path, todo_item)
    
    if success then
        vim.notify("Todo added: " .. todo_text, vim.log.levels.INFO)
        -- Reload the file if it's currently open
        local bufnr = vim.fn.bufnr(active_path)
        if bufnr ~= -1 then
            vim.cmd('edit!')
        end
    else
        vim.notify("Failed to add todo", vim.log.levels.ERROR)
    end
end

-- Complete a todo item
function M.complete_todo()
    local active_path = state.todo_dir .. "/" .. state.active_todo_file
    local completed_path = state.todo_dir .. "/" .. state.completed_todo_file
    
    -- Get current line and buffer details
    local current_line = vim.fn.getline('.')
    local current_bufnr = vim.api.nvim_get_current_buf()
    local current_file = vim.api.nvim_buf_get_name(current_bufnr)
    
    -- Determine if we're in the active todos file
    local is_active_todos_file = current_file:match(active_path .. "$")
    
    -- Check if line is a todo item
    if current_line:match("^%- %[ %]") then
        -- Remove checkbox and mark as completed
        local todo_text = current_line:gsub("^%- %[ %] ", "")
        local completion_date = os.date("%Y-%m-%d %H:%M:%S")
        
        -- Completed todo item
        local completed_item = "- [x] " .. todo_text .. " (Completed: " .. completion_date .. ")\n"
        
        -- Append to completed todos
        local success_completed = write_to_file(completed_path, completed_item)
        
        if is_active_todos_file then
            -- Remove from active todos
            local active_content = read_file(active_path)
            if active_content then
                -- Remove the completed line
                active_content = active_content:gsub(vim.pesc(current_line), "")
                
                -- Write back to active todos file
                local success_active = write_to_file(active_path, active_content, "w")
                
                if success_completed and success_active then
                    vim.notify("Todo completed: " .. todo_text, vim.log.levels.INFO)
                    
                    -- Reload the file
                    vim.cmd('edit!')
                else
                    vim.notify("Failed to complete todo", vim.log.levels.ERROR)
                end
            end
        end
    else
        vim.notify("Current line is not a todo item", vim.log.levels.WARN)
    end
end

-- Open todo files or use Telescope if available
function M.open_todos()
    local active_path = state.todo_dir .. "/" .. state.active_todo_file
    vim.cmd('edit ' .. active_path)
end

function M.open_completed_todos()
    local completed_path = state.todo_dir .. "/" .. state.completed_todo_file
    vim.cmd('edit ' .. completed_path)
end

-- Setup function for the plugin
function M.setup(opts)
    -- Merge user config with default config
    opts = opts or {}
    for k, v in pairs(opts) do
        -- Sanitize todo_dir to remove trailing slashes
        if k == "todo_dir" then
            M.config[k] = sanitize_path(v)
        else
            M.config[k] = v
        end
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
    
    -- Set up keymappings
    vim.api.nvim_set_keymap('n', '<leader>ta', ':TodoAdd ', { noremap = true, silent = false, desc = 'Add Todo' })
    vim.api.nvim_set_keymap('n', '<leader>tc', ':TodoComplete<CR>', { noremap = true, silent = true, desc = 'Complete Todo' })
    vim.api.nvim_set_keymap('n', '<leader>tl', ':TodoList<CR>', { noremap = true, silent = true, desc = 'List Todos' })
    vim.api.nvim_set_keymap('n', '<leader>td', ':TodoCompletedList<CR>', { noremap = true, silent = true, desc = 'List Completed Todos' })
end

-- Debug function to print current configuration
function M.debug_config()
    print("Todo Directory: " .. state.todo_dir)
    print("Active Todo File: " .. state.todo_dir .. "/" .. state.active_todo_file)
    print("Completed Todo File: " .. state.todo_dir .. "/" .. state.completed_todo_file)
end

return M
