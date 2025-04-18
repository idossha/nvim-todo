local M = {}
local utils = require('nvim-todo.utils')
local config = require('nvim-todo.config')

-- Ensure todo files exist with proper initial content
function M.ensure_todo_files()
    -- Get paths
    local active_path = config.get_active_todo_path()
    local completed_path = config.get_completed_todo_path()
    local stats_path = config.get_statistics_path()

    -- Function to create file with initial content if it doesn't exist
    local function create_file_if_not_exists(path, initial_content)
        if not utils.file_exists(path) then
            utils.write_to_file(path, initial_content or "# Todos\n", "w")
        else
            -- Check if file is empty
            local content = utils.read_file(path)
            if not content or content == "" then
                utils.write_to_file(path, initial_content or "# Todos\n", "w")
            end
        end
    end

    -- Create files with initial content
    create_file_if_not_exists(active_path, "# Active Todos\n## Tasks\n")
    create_file_if_not_exists(completed_path, "# Completed Todos\n## History\n")
    create_file_if_not_exists(stats_path, "# Todo Statistics\n")

    return true
end

-- Add a todo item to the active todo file
function M.add_todo(todo_text)
    local active_path = config.get_active_todo_path()
    
    -- Generate timestamp for creation
    local creation_timestamp = utils.generate_timestamp()
    
    -- Prepare todo item with timestamp
    local todo_item = string.format("- [ ] %s (Created: %s)\n", todo_text, creation_timestamp)
    
    -- Append to file
    local success = utils.write_to_file(active_path, todo_item)
    
    if success then
        vim.notify("Todo added: " .. todo_text, vim.log.levels.INFO)
        
        -- Reload the file if it's currently open
        local bufnr = vim.fn.bufnr(active_path)
        if bufnr ~= -1 then
            vim.cmd('checktime ' .. bufnr)
        end
        
        return true
    else
        vim.notify("Failed to add todo to file", vim.log.levels.ERROR)
        return false
    end
end

-- Parse todo files to extract todos
function M.parse_todos(file_path)
    local content = utils.read_file(file_path)
    if not content then
        return {}
    end
    
    local todos = {}
    for line in content:gmatch("[^\r\n]+") do
        -- Skip header lines
        if not line:match("^#") then
            -- Look for todo items with checkbox "- [ ]" or "- [x]"
            local checkbox, text = line:match("^%s*%-%s*%[([%s%a])%]%s*(.*)")
            if checkbox and text then
                local is_complete = checkbox:lower() == "x"
                
                -- Extract creation timestamp
                local content, creation_time = text:match("(.-)%(Created:%s*(.-)%)")
                content = content and content:gsub("%s+$", "") or text
                
                -- Extract completion timestamp if present
                local completion_time = nil
                if is_complete then
                    local completion_match = text:match("%(Completed:%s*(.-)%)")
                    if completion_match then
                        completion_time = completion_match
                    end
                end
                
                table.insert(todos, {
                    content = content or text,
                    created_at = creation_time,
                    completed_at = completion_time,
                    status = is_complete and "completed" or "active"
                })
            end
        end
    end
    
    return todos
end

-- Complete a todo by line number in the active todo file
function M.complete_todo_by_line(line_number)
    local active_path = config.get_active_todo_path() 
    local completed_path = config.get_completed_todo_path()
    
    -- Read all lines from the active todo file
    local content = utils.read_file(active_path)
    if not content then
        vim.notify("Failed to read active todo file", vim.log.levels.ERROR)
        return false
    end
    
    local lines = {}
    for line in content:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end
    
    -- Check if line number is valid
    if line_number <= 0 or line_number > #lines then
        vim.notify("Invalid line number: " .. line_number, vim.log.levels.ERROR)
        return false
    end
    
    -- Get the todo line
    local todo_line = lines[line_number]
    
    -- Check if it's a valid todo item
    local checkbox, text = todo_line:match("^%s*%-%s*%[([%s%a])%]%s*(.*)")
    if not checkbox or not text then
        vim.notify("Selected line is not a valid todo item", vim.log.levels.ERROR)
        return false
    end
    
    -- Mark as completed
    local completion_timestamp = utils.generate_timestamp()
    local completed_todo = todo_line:gsub("%[%s%]", "[x]") .. " (Completed: " .. completion_timestamp .. ")"
    
    -- Remove from active todo file
    table.remove(lines, line_number)
    
    -- Write updated active todo file
    local success = utils.write_to_file(active_path, table.concat(lines, "\n"), "w")
    if not success then
        vim.notify("Failed to update active todo file", vim.log.levels.ERROR)
        return false
    end
    
    -- Append to completed todo file
    success = utils.write_to_file(completed_path, completed_todo .. "\n")
    if not success then
        vim.notify("Failed to update completed todo file", vim.log.levels.ERROR)
        return false
    end
    
    -- Notify user
    vim.notify("Todo completed", vim.log.levels.INFO)
    
    -- Reload buffers if open
    local active_bufnr = vim.fn.bufnr(active_path)
    if active_bufnr ~= -1 then
        vim.cmd('checktime ' .. active_bufnr)
    end
    
    local completed_bufnr = vim.fn.bufnr(completed_path)
    if completed_bufnr ~= -1 then
        vim.cmd('checktime ' .. completed_bufnr)
    end
    
    return true
end

-- Search for todos in file
function M.search_todos(search_term)
    local active_path = config.get_active_todo_path()
    local completed_path = config.get_completed_todo_path()
    
    local results = {}
    
    -- Search in active todos
    local active_todos = M.parse_todos(active_path)
    for _, todo in ipairs(active_todos) do
        if todo.content:lower():find(search_term:lower()) then
            table.insert(results, { 
                content = todo.content,
                status = "active",
                created_at = todo.created_at
            })
        end
    end
    
    -- Search in completed todos
    local completed_todos = M.parse_todos(completed_path)
    for _, todo in ipairs(completed_todos) do
        if todo.content:lower():find(search_term:lower()) then
            table.insert(results, { 
                content = todo.content,
                status = "completed",
                created_at = todo.created_at,
                completed_at = todo.completed_at
            })
        end
    end
    
    return results
end

return M 