local M = {}

-- Utility function to create directory
local function create_directory(path)
    -- Use vim's mkdir to ensure correct path handling
    local success, err = pcall(function()
        vim.fn.mkdir(path, "p")
    end)
    
    if not success then
        vim.notify("Failed to create directory: " .. path .. "\nError: " .. tostring(err), vim.log.levels.ERROR)
        return false
    end
    return true
end

-- Require telescope (optional dependency)
local has_telescope, telescope = pcall(require, 'telescope.builtin')

-- Plugin configuration with default values
M.config = {
    -- Default path for todo files
    todo_dir = "/tmp/todo",
    -- Default filename for active todos
    active_todo_file = "todos.md",
    -- Default filename for completed todos
    completed_todo_file = "completed_todos.md",
    -- Use telescope if available
    use_telescope = has_telescope
}

-- Internal state
local state = {
    todo_dir = nil,
    active_todo_file = nil,
    completed_todo_file = nil
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

    return true
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
    
    if M.config.use_telescope and telescope then
        -- Use Telescope to list todos if available
        telescope.find_files({
            prompt_title = "Active Todos",
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
    else
        -- Fallback to direct file opening
        vim.cmd('edit ' .. active_path)
    end
end

function M.open_completed_todos()
    local completed_path = state.todo_dir .. "/" .. state.completed_todo_file
    
    if M.config.use_telescope and telescope then
        -- Use Telescope to list completed todos if available
        telescope.find_files({
            prompt_title = "Completed Todos",
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
    else
        -- Fallback to direct file opening
        vim.cmd('edit ' .. completed_path)
    end
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
