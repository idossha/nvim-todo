local M = {}
local utils = require('nvim-todo.utils')
local config_module = require('nvim-todo.config')

-- Check if lsqlite3 is available
local has_sqlite, sqlite = pcall(require, 'lsqlite3')
if not has_sqlite then
    vim.notify("SQLite3 not found. Please install lsqlite3 for Lua.", vim.log.levels.ERROR)
    return M
end

-- Internal database configuration
local db_config = {
    initialized = false
}

-- Create and initialize the database
local function initialize_db()
    if db_config.initialized then
        return true
    end
    
    local config = config_module.get()
    
    -- Create the database connection
    local db = sqlite.open(config.db_path)
    if not db then
        vim.notify("Failed to open database: " .. config.db_path, vim.log.levels.ERROR)
        return false
    end
    
    -- Create tables if they don't exist
    local create_todos_table = [[
        CREATE TABLE IF NOT EXISTS todos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            content TEXT NOT NULL,
            created_at TEXT NOT NULL,
            completed_at TEXT,
            status TEXT NOT NULL DEFAULT 'active'
        );
    ]]
    
    local create_statistics_table = [[
        CREATE TABLE IF NOT EXISTS statistics (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            metric TEXT NOT NULL,
            value REAL NOT NULL,
            updated_at TEXT NOT NULL
        );
    ]]
    
    local create_settings_table = [[
        CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );
    ]]
    
    local create_tags_table = [[
        CREATE TABLE IF NOT EXISTS tags (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE NOT NULL
        );
    ]]
    
    local create_todo_tags_table = [[
        CREATE TABLE IF NOT EXISTS todo_tags (
            todo_id INTEGER,
            tag_id INTEGER,
            PRIMARY KEY (todo_id, tag_id),
            FOREIGN KEY (todo_id) REFERENCES todos(id) ON DELETE CASCADE,
            FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
        );
    ]]
    
    local success = true
    success = success and db:exec(create_todos_table) == sqlite.OK
    success = success and db:exec(create_statistics_table) == sqlite.OK
    success = success and db:exec(create_settings_table) == sqlite.OK
    success = success and db:exec(create_tags_table) == sqlite.OK
    success = success and db:exec(create_todo_tags_table) == sqlite.OK
    
    db:close()
    
    if success then
        db_config.initialized = true
        return true
    else
        vim.notify("Failed to initialize database schema", vim.log.levels.ERROR)
        return false
    end
end

-- Execute SQL with parameters safely
local function execute_query(query, params)
    local config = config_module.get()
    local db = sqlite.open(config.db_path)
    if not db then
        vim.notify("Failed to open database", vim.log.levels.ERROR)
        return false
    end
    
    local stmt = db:prepare(query)
    if not stmt then
        vim.notify("Failed to prepare statement: " .. query, vim.log.levels.ERROR)
        db:close()
        return false
    end
    
    -- Bind parameters if provided
    if params then
        for i, v in pairs(params) do
            if type(i) == "number" then
                stmt:bind(i, v)
            elseif type(i) == "string" then
                stmt:bind_names({[i] = v})
            end
        end
    end
    
    local result = stmt:step() == sqlite.DONE
    stmt:finalize()
    db:close()
    
    return result
end

-- Query data from the database
local function query_data(query, params)
    local config = config_module.get()
    local db = sqlite.open(config.db_path)
    if not db then
        vim.notify("Failed to open database", vim.log.levels.ERROR)
        return nil
    end
    
    local stmt = db:prepare(query)
    if not stmt then
        vim.notify("Failed to prepare statement: " .. query, vim.log.levels.ERROR)
        db:close()
        return nil
    end
    
    -- Bind parameters if provided
    if params then
        for i, v in pairs(params) do
            if type(i) == "number" then
                stmt:bind(i, v)
            elseif type(i) == "string" then
                stmt:bind_names({[i] = v})
            end
        end
    end
    
    local results = {}
    while stmt:step() == sqlite.ROW do
        local row = {}
        for i = 0, stmt:columns() - 1 do
            local column_name = stmt:column_name(i)
            local value = stmt:column_value(i)
            row[column_name] = value
        end
        table.insert(results, row)
    end
    
    stmt:finalize()
    db:close()
    
    return results
end

-- Setup the database
function M.setup()
    -- Initialize the database
    return initialize_db()
end

-- Add a new todo item
function M.add_todo(content)
    local timestamp = utils.generate_timestamp()
    
    local query = [[
        INSERT INTO todos (content, created_at, status)
        VALUES (?, ?, 'active');
    ]]
    
    -- Extract tags from content
    local tags = utils.extract_tags(content)
    
    -- Begin transaction
    local config = config_module.get()
    local db = sqlite.open(config.db_path)
    if not db then
        vim.notify("Failed to open database", vim.log.levels.ERROR)
        return false
    end
    
    -- Start transaction
    db:exec("BEGIN TRANSACTION;")
    
    -- Insert todo
    local todo_stmt = db:prepare(query)
    if not todo_stmt then
        db:exec("ROLLBACK;")
        db:close()
        vim.notify("Failed to prepare statement for adding todo", vim.log.levels.ERROR)
        return false
    end
    
    todo_stmt:bind(1, content)
    todo_stmt:bind(2, timestamp)
    
    local success = todo_stmt:step() == sqlite.DONE
    todo_stmt:finalize()
    
    if success and #tags > 0 then
        -- Get the last inserted todo ID
        local todo_id = db:last_insert_rowid()
        
        -- Insert or get tag IDs for each tag
        for _, tag in ipairs(tags) do
            -- Check if tag exists
            local tag_check_stmt = db:prepare("SELECT id FROM tags WHERE name = ?")
            tag_check_stmt:bind(1, tag)
            
            local tag_id = nil
            if tag_check_stmt:step() == sqlite.ROW then
                tag_id = tag_check_stmt:column_value(0)
            end
            tag_check_stmt:finalize()
            
            -- If tag doesn't exist, create it
            if not tag_id then
                local tag_insert_stmt = db:prepare("INSERT INTO tags (name) VALUES (?)")
                tag_insert_stmt:bind(1, tag)
                
                if tag_insert_stmt:step() ~= sqlite.DONE then
                    success = false
                    tag_insert_stmt:finalize()
                    break
                end
                
                tag_id = db:last_insert_rowid()
                tag_insert_stmt:finalize()
            end
            
            -- Link tag to todo
            local link_stmt = db:prepare("INSERT INTO todo_tags (todo_id, tag_id) VALUES (?, ?)")
            link_stmt:bind(1, todo_id)
            link_stmt:bind(2, tag_id)
            
            if link_stmt:step() ~= sqlite.DONE then
                success = false
                link_stmt:finalize()
                break
            end
            
            link_stmt:finalize()
        end
    end
    
    -- Commit or rollback based on success
    if success then
        db:exec("COMMIT;")
    else
        db:exec("ROLLBACK;")
    end
    
    db:close()
    
    return success
end

-- Complete a todo item
function M.complete_todo(todo_id)
    local timestamp = utils.generate_timestamp()
    
    local query = [[
        UPDATE todos
        SET status = 'completed', completed_at = ?
        WHERE id = ? AND status = 'active';
    ]]
    
    return execute_query(query, {timestamp, todo_id})
end

-- Get all active todos
function M.get_active_todos()
    local query = [[
        SELECT id, content, created_at
        FROM todos
        WHERE status = 'active'
        ORDER BY created_at DESC;
    ]]
    
    return query_data(query)
end

-- Get all completed todos
function M.get_completed_todos()
    local query = [[
        SELECT id, content, created_at, completed_at
        FROM todos
        WHERE status = 'completed'
        ORDER BY completed_at DESC;
    ]]
    
    return query_data(query)
end

-- Get todos by tag
function M.get_todos_by_tag(tag)
    local query = [[
        SELECT t.id, t.content, t.created_at, t.completed_at, t.status
        FROM todos t
        JOIN todo_tags tt ON t.id = tt.todo_id
        JOIN tags tg ON tt.tag_id = tg.id
        WHERE tg.name = ?
        ORDER BY 
            CASE WHEN t.status = 'active' THEN 0 ELSE 1 END,
            CASE WHEN t.status = 'active' THEN t.created_at ELSE t.completed_at END DESC;
    ]]
    
    return query_data(query, {tag})
end

-- Search todos
function M.search_todos(search_term)
    local query = [[
        SELECT id, content, created_at, completed_at, status
        FROM todos
        WHERE content LIKE ?
        ORDER BY 
            CASE WHEN status = 'active' THEN 0 ELSE 1 END,
            CASE WHEN status = 'active' THEN created_at ELSE completed_at END DESC;
    ]]
    
    return query_data(query, {'%' .. search_term .. '%'})
end

-- Calculate statistics
function M.calculate_statistics()
    -- Query to get counts
    local counts_query = [[
        SELECT 
            (SELECT COUNT(*) FROM todos) as total_count,
            (SELECT COUNT(*) FROM todos WHERE status = 'active') as active_count,
            (SELECT COUNT(*) FROM todos WHERE status = 'completed') as completed_count
    ]]
    
    -- Query to get completion times
    local completion_times_query = [[
        SELECT 
            julianday(completed_at) - julianday(created_at) AS completion_time_days
        FROM todos
        WHERE status = 'completed'
    ]]
    
    -- Get counts
    local counts = query_data(counts_query)[1]
    
    -- Get completion times
    local completion_times = query_data(completion_times_query)
    
    -- Calculate completion rate
    local completion_rate = 0
    if counts.total_count > 0 then
        completion_rate = (counts.completed_count / counts.total_count) * 100
    end
    
    -- Calculate average completion time and standard deviation
    local avg_completion_time = 0
    local std_dev_completion_time = 0
    
    if #completion_times > 0 then
        -- Calculate sum of completion times
        local sum = 0
        for _, row in ipairs(completion_times) do
            sum = sum + row.completion_time_days
        end
        
        -- Convert from days to hours
        avg_completion_time = (sum / #completion_times) * 24
        
        -- Calculate standard deviation
        if #completion_times > 1 then
            local variance = 0
            for _, row in ipairs(completion_times) do
                local diff = (row.completion_time_days * 24) - avg_completion_time
                variance = variance + (diff * diff)
            end
            
            variance = variance / (#completion_times - 1)
            std_dev_completion_time = math.sqrt(variance)
        end
    end
    
    return {
        total_count = counts.total_count,
        active_count = counts.active_count,
        completed_count = counts.completed_count,
        completion_rate = completion_rate,
        avg_completion_time = avg_completion_time,
        std_dev_completion_time = std_dev_completion_time
    }
end

return M
