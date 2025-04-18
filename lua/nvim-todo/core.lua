local M = {}

-- Require telescope and stats module
local has_telescope, telescope = pcall(require, 'telescope.builtin')
local stats_module = require('nvim-todo.stats')

-- Utility function to create directory
local function create_directory(path)
    local success, err = pcall(function()
        vim.fn.mkdir(path, "p")
    end)
    
    if not success then
        vim.notify("Failed to create directory: " .. path .. "\nError: " .. tostring(err), vim.log.levels.ERROR)
        return false
    end
    return true
end

-- Generate a unique timestamp
local function generate_timestamp()
    return os.date("%Y-%m-%d %H:%M:%S")
end

-- Plugin configuration with default values
M.config = {
    -- Default path for todo files
    todo_dir = "/tmp/todo",
    -- Filenames for different todo types
    active_todo_file = "todos.md",
    completed_todo_file = "completed_todos.md",
    statistics_file = "todo_stats.md",
    -- Use telescope if available
    use_telescope = has_telescope
}

-- Internal state
local state = {
    todo_dir = nil,
    active_todo_file = nil,
    completed_todo_file = nil,
    statistics_file = nil
}

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

-- Ensure todo directory and files exist with proper initial content
local function ensure_todo_files()
    -- Create todo directory if it doesn't exist
    if not create_directory(state.todo_dir) then
        return false
    end

    -- Paths for todo files
    local active_path = state.todo_dir .. "/" .. state.active_todo_file
    local completed_path = state.todo_dir .. "/" .. state.completed_todo_file
    local stats_path = state.todo_dir .. "/" .. state.statistics_file

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
    create_file_if_not_exists(active_path, "# Active Todos\n## Tasks\n")
    create_file_if_not_exists(completed_path, "# Completed Todos\n## History\n")
    create_file_if_not_exists(stats_path, "# Todo Statistics\n")

    return true
end

-- Open statistics file with calculated stats
function M.open_statistics()
    local active_path = state.todo_dir .. "/" .. state.active_todo_file
    local completed_path = state.todo_dir .. "/" .. state.completed_todo_file
    local stats_path = state.todo_dir .. "/" .. state.statistics_file
    
    -- Calculate and update statistics
    stats_module.update_statistics_file(active_path, completed_path, stats_path)
    
    -- Open the stats file
    vim.cmd('edit ' .. stats_path)
end

-- Add a new todo item
function M.add_todo(todo_text)
    local active_path = state.todo_dir .. "/" .. state.active_todo_file
    local stats_path = state.todo_dir .. "/" .. state.statistics_file
    
    -- Generate timestamp for creation
    local creation_timestamp = generate_timestamp()
    
    -- Prepare todo item with timestamp
    local todo_item = string.format("- [ ] %s (Created: %s)\n", todo_text, creation_timestamp)
    
    -- Append to file
    local success = write_to_file(active_path, todo_item)
    
    if success then
        vim.notify("Todo added: " .. todo_text, vim.log.levels.INFO)
        
        -- Reload the file if it's currently open
        local bufnr = vim.fn.bufnr(active_path)
        if bufnr ~= -1 then
            vim.cmd('edit!')
        end
        
        -- Update statistics file silently
        stats_module.update_statistics_file(active_path, 
            state.todo_dir .. "/" .. state.completed_todo_file, 
            stats_path)
        
        -- Refresh stats buffer if open
        local stats_bufnr = vim.fn.bufnr(stats_path)
        if stats_bufnr ~= -1 then
            vim.api.nvim_buf_call(stats_bufnr, function()
                vim.cmd('edit!')
            end)
        end
    else
        vim.notify("Failed to add todo", vim.log.levels.ERROR)
    end
end

-- Complete a todo item
function M.complete_todo()
    local active_path = state.todo_dir .. "/" .. state.active_todo_file
    local completed_path = state.todo_dir .. "/" .. state.completed_todo_file
    local stats_path = state.todo_dir .. "/" .. state.statistics_file
    
    -- Get current line and buffer details
    local current_line = vim.fn.getline('.')
    local current_bufnr = vim.api.nvim_get_current_buf()
    local current_file = vim.api.nvim_buf_get_name(current_bufnr)
    
    -- Determine if we're in the active todos file
    local is_active_todos_file = current_file:match(active_path .. "$")
    
    -- Check if line is a todo item
    if current_line:match("^%- %[ %]") then
        -- Remove checkbox and mark as completed
        local todo_text = current_line:gsub("^%- %[ %] ", ""):gsub("%s*$", "")
        local completion_date = generate_timestamp()
        
        -- Completed todo item
        local completed_item = string.format("- [x] %s (Completed: %s)\n", todo_text, completion_date)
        
        -- Append to completed todos
        local success_completed = write_to_file(completed_path, completed_item)
        
        if is_active_todos_file then
            -- Remove from active todos
            local active_content = read_file(active_path)
            if active_content then
                -- Remove the completed line, trimming trailing whitespace
                active_content = active_content:gsub(vim.pesc(current_line), "")
                
                -- Write back to active todos file
                local success_active = write_to_file(active_path, active_content, "w")
                
                if success_completed and success_active then
                    vim.notify("Todo completed: " .. todo_text, vim.log.levels.INFO)
                    
                    -- Update statistics file silently
                    stats_module.update_statistics_file(active_path, completed_path, stats_path)
                    
                    -- Reload the file
                    vim.cmd('edit!')
                    
                    -- Refresh stats buffer if open
                    local stats_bufnr = vim.fn.bufnr(stats_path)
                    if stats_bufnr ~= -1 then
                        vim.api.nvim_buf_call(stats_bufnr, function()
                            vim.cmd('edit!')
                        end)
                    end
                else
                    vim.notify("Failed to complete todo", vim.log.levels.ERROR)
                end
            end
        end
    else
        vim.notify("Current line is not a todo item", vim.log.levels.WARN)
    end
end

-- Telescope file finder within todo directory
function M.find_todo_files()
    if not has_telescope then
        vim.notify("Telescope is not installed", vim.log.levels.ERROR)
        return
    end
    
    telescope.find_files({
        prompt_title = "Todo Files",
        cwd = state.todo_dir,
        attach_mappings = function(prompt_bufnr)
            local actions = require('telescope.actions')
            actions.select_default:replace(function()
                actions.close(prompt_bufnr)
                local selection = require('telescope.actions.state').get_selected_entry()
                if selection then
                    vim.cmd('edit ' .. selection[1])
                end
            end)
            return true
        end
    })
end

-- Telescope live grep within todo directory
function M.live_grep_todos()
    if not has_telescope then
        vim.notify("Telescope is not installed", vim.log.levels.ERROR)
        return
    end
    
    telescope.live_grep({
        prompt_title = "Search Todos",
        cwd = state.todo_dir,
    })
end

-- Open todo files
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
        -- Remove any trailing slashes for todo_dir
        if k == "todo_dir" then
            M.config[k] = v:gsub("/*$", "")
        else
            M.config[k] = v
        end
    end
    
    -- Set internal state
    state.todo_dir = M.config.todo_dir
    state.active_todo_file = M.config.active_todo_file
    state.completed_todo_file = M.config.completed_todo_file
    state.statistics_file = M.config.statistics_file
    
    -- Ensure todo files exist
    if not ensure_todo_files() then
        vim.notify("Failed to set up Nvim Todo plugin", vim.log.levels.ERROR)
        return
    end
    
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
    
    vim.api.nvim_create_user_command('TodoStats', M.open_statistics, {
        desc = 'Open todo statistics'
    })
    
    vim.api.nvim_create_user_command('TodoFindFiles', M.find_todo_files, {
        desc = 'Find files in todo directory'
    })
    
    vim.api.nvim_create_user_command('TodoLiveGrep', M.live_grep_todos, {
        desc = 'Live grep in todo directory'
    })
    
    -- Set up keymappings
    vim.api.nvim_set_keymap('n', '<leader>ta', ':TodoAdd ', { noremap = true, silent = false, desc = 'Add Todo' })
    vim.api.nvim_set_keymap('n', '<leader>tc', ':TodoComplete<CR>', { noremap = true, silent = true, desc = 'Complete Todo' })
    vim.api.nvim_set_keymap('n', '<leader>tl', ':TodoList<CR>', { noremap = true, silent = true, desc = 'List Todos' })
    vim.api.nvim_set_keymap('n', '<leader>td', ':TodoCompletedList<CR>', { noremap = true, silent = true, desc = 'List Completed Todos' })
    vim.api.nvim_set_keymap('n', '<leader>ts', ':TodoStats<CR>', { noremap = true, silent = true, desc = 'Todo Statistics' })
    vim.api.nvim_set_keymap('n', '<leader>tf', ':TodoFindFiles<CR>', { noremap = true, silent = true, desc = 'Find Todo Files' })
    vim.api.nvim_set_keymap('n', '<leader>tg', ':TodoLiveGrep<CR>', { noremap = true, silent = true, desc = 'Live Grep Todos' })
end

-- Debug function to print current configuration
function M.debug_config()
    print("Todo Directory: " .. state.todo_dir)
    print("Active Todo File: " .. state.todo_dir .. "/" .. state.active_todo_file)
    print("Completed Todo File: " .. state.todo_dir .. "/" .. state.completed_todo_file)
    print("Statistics File: " .. state.todo_dir .. "/" .. state.statistics_file)
end

return M
