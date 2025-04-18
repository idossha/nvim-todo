local M = {}
local utils = require('todo.utils')
local config_module

-- Delay the loading of config_module to avoid circular dependency
local function get_config()
    if not config_module then
        config_module = require('todo.config')
    end
    return config_module
end

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
    
    local config = get_config().get()
    
    -- Create the database connection
    local db = sqlite.open(config.db_path)
    if not db then
        vim.notify("Failed to open database: " .. config.db_path, vim.log.levels.ERROR)
        return false
    end
    
    -- Create tables if they don't exist with more fields for better organization
    local create_todos_table = [[
        CREATE TABLE IF NOT EXISTS todos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            content TEXT NOT NULL,
            created_at TEXT NOT NULL,
            completed_at TEXT,
            status TEXT NOT NULL DEFAULT 'active',
            priority INTEGER DEFAULT 0,
            due_date TEXT,
            notes TEXT
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
    
    local create_projects_table = [[
        CREATE TABLE IF NOT EXISTS projects (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE NOT NULL,
            description TEXT,
            created_at TEXT NOT NULL
        );
    ]]
    
    local create_todo_projects_table = [[
        CREATE TABLE IF NOT EXISTS todo_projects (
            todo_id INTEGER,
            project_id INTEGER,
            PRIMARY KEY (todo_id, project_id),
            FOREIGN KEY (todo_id) REFERENCES todos(id) ON DELETE CASCADE,
            FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
        );
    ]]
    
    local success = true
    success = success and db:exec(create_todos_table) == sqlite.OK
    success = success and db:exec(create_statistics_table) == sqlite.OK
    success = success and db:exec(create_settings_table) == sqlite.OK
    success = success and db:exec(create_tags_table) == sqlite.OK
    success = success and db:exec(create_todo_tags_table) == sqlite.OK
    success = success and db:exec(create_projects_table) == sqlite.OK
    success = success and db:exec(create_todo_projects_table) == sqlite.OK
    
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
    local config = get_config().get()
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
    local config = get_config().get()
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
    if initialize_db() then
        -- Update stats after initialization
        M.calculate_statistics()
        return true
    end
    return false
end

-- Add a new todo item
function M.add_todo(content, options)
    options = options or {}
    local timestamp = utils.generate_timestamp()
    
    local query = [[
        INSERT INTO todos (content, created_at, status, priority, due_date, notes)
        VALUES (?, ?, 'active', ?, ?, ?);
    ]]
    
    -- Extract tags from content
    local tags = utils.extract_tags(content)
    
    -- Begin transaction
    local config = get_config().get()
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
    todo_stmt:bind(3, options.priority or 0)
    todo_stmt:bind(4, options.due_date or "")
    todo_stmt:bind(5, options.notes or "")
    
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
    
    if options.project then
        local todo_id = db:last_insert_rowid()
        
        -- Check if project exists
        local project_check_stmt = db:prepare("SELECT id FROM projects WHERE name = ?")
        project_check_stmt:bind(1, options.project)
        
        local project_id = nil
        if project_check_stmt:step() == sqlite.ROW then
            project_id = project_check_stmt:column_value(0)
        end
        project_check_stmt:finalize()
        
        -- If project doesn't exist, create it
        if not project_id then
            local project_insert_stmt = db:prepare("INSERT INTO projects (name, created_at) VALUES (?, ?)")
            project_insert_stmt:bind(1, options.project)
            project_insert_stmt:bind(2, timestamp)
            
            if project_insert_stmt:step() ~= sqlite.DONE then
                success = false
                project_insert_stmt:finalize()
            else
                project_id = db:last_insert_rowid()
                project_insert_stmt:finalize()
            end
        end
        
        -- Link todo to project
        if project_id then
            local link_stmt = db:prepare("INSERT INTO todo_projects (todo_id, project_id) VALUES (?, ?)")
            link_stmt:bind(1, todo_id)
            link_stmt:bind(2, project_id)
            
            if link_stmt:step() ~= sqlite.DONE then
                success = false
                link_stmt:finalize()
            else
                link_stmt:finalize()
            end
        end
    end
    
    -- Commit or rollback based on success
    if success then
        db:exec("COMMIT;")
        -- Update statistics
        M.calculate_statistics()
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
    
    local success = execute_query(query, {timestamp, todo_id})
    
    if success then
        -- Update statistics
        M.calculate_statistics()
    end
    
    return success
end

-- Delete a todo item
function M.delete_todo(todo_id)
    local query = [[
        DELETE FROM todos
        WHERE id = ?;
    ]]
    
    local success = execute_query(query, {todo_id})
    
    if success then
        -- Update statistics
        M.calculate_statistics()
    end
    
    return success
end

-- Update a todo item
function M.update_todo(todo_id, updates)
    if not updates or vim.tbl_isempty(updates) then
        return false
    end
    
    -- Build the update query dynamically
    local set_clauses = {}
    local params = {}
    
    for field, value in pairs(updates) do
        if field ~= "id" then -- Prevent updating the primary key
            table.insert(set_clauses, field .. " = ?")
            table.insert(params, value)
        end
    end
    
    if #set_clauses == 0 then
        return false
    end
    
    -- Add the todo_id to the params
    table.insert(params, todo_id)
    
    local query = string.format([[
        UPDATE todos
        SET %s
        WHERE id = ?;
    ]], table.concat(set_clauses, ", "))
    
    local success = execute_query(query, params)
    
    if success then
        -- Update statistics
        M.calculate_statistics()
    end
    
    return success
end

-- Get all active todos with optional filtering
function M.get_active_todos(filters)
    local query_parts = {
        "SELECT t.id, t.content, t.created_at, t.priority, t.due_date, t.notes",
        "FROM todos t",
        "WHERE t.status = 'active'"
    }
    
    local params = {}
    
    -- Process filters
    if filters then
        if filters.tag then
            table.insert(query_parts, 2, "JOIN todo_tags tt ON t.id = tt.todo_id")
            table.insert(query_parts, 3, "JOIN tags tg ON tt.tag_id = tg.id")
            table.insert(query_parts, #query_parts + 1, "AND tg.name = ?")
            table.insert(params, filters.tag)
        end
        
        if filters.project then
            table.insert(query_parts, 2, "JOIN todo_projects tp ON t.id = tp.todo_id")
            table.insert(query_parts, 3, "JOIN projects p ON tp.project_id = p.id")
            table.insert(query_parts, #query_parts + 1, "AND p.name = ?")
            table.insert(params, filters.project)
        end
        
        if filters.search then
            table.insert(query_parts, #query_parts + 1, "AND t.content LIKE ?")
            table.insert(params, '%' .. filters.search .. '%')
        end
        
        if filters.priority then
            table.insert(query_parts, #query_parts + 1, "AND t.priority >= ?")
            table.insert(params, filters.priority)
        end
        
        if filters.due_before then
            table.insert(query_parts, #query_parts + 1, "AND t.due_date <= ? AND t.due_date != ''")
            table.insert(params, filters.due_before)
        end
    end
    
    -- Add order clause
    table.insert(query_parts, "ORDER BY CASE WHEN t.due_date = '' THEN 1 ELSE 0 END, t.due_date, t.priority DESC, t.created_at")
    
    local query = table.concat(query_parts, " ")
    return query_data(query, params)
end

-- Get all completed todos with optional filtering
function M.get_completed_todos(filters)
    local query_parts = {
        "SELECT t.id, t.content, t.created_at, t.completed_at, t.priority",
        "FROM todos t",
        "WHERE t.status = 'completed'"
    }
    
    local params = {}
    
    -- Process filters
    if filters then
        if filters.tag then
            table.insert(query_parts, 2, "JOIN todo_tags tt ON t.id = tt.todo_id")
            table.insert(query_parts, 3, "JOIN tags tg ON tt.tag_id = tg.id")
            table.insert(query_parts, #query_parts + 1, "AND tg.name = ?")
            table.insert(params, filters.tag)
        end
        
        if filters.project then
            table.insert(query_parts, 2, "JOIN todo_projects tp ON t.id = tp.todo_id")
            table.insert(query_parts, 3, "JOIN projects p ON tp.project_id = p.id")
            table.insert(query_parts, #query_parts + 1, "AND p.name = ?")
            table.insert(params, filters.project)
        end
        
        if filters.search then
            table.insert(query_parts, #query_parts + 1, "AND t.content LIKE ?")
            table.insert(params, '%' .. filters.search .. '%')
        end
        
        if filters.completed_after then
            table.insert(query_parts, #query_parts + 1, "AND t.completed_at >= ?")
            table.insert(params, filters.completed_after)
        end
    end
    
    -- Add order clause
    table.insert(query_parts, "ORDER BY t.completed_at DESC")
    
    local query = table.concat(query_parts, " ")
    return query_data(query, params)
end

-- Get all tags
function M.get_tags()
    local query = [[
        SELECT t.id, t.name, COUNT(tt.todo_id) as todo_count
        FROM tags t
        LEFT JOIN todo_tags tt ON t.id = tt.tag_id
        GROUP BY t.id
        ORDER BY todo_count DESC, t.name
    ]]
    
    return query_data(query)
end

-- Get all projects
function M.get_projects()
    local query = [[
        SELECT p.id, p.name, p.description, p.created_at, 
               COUNT(tp.todo_id) as todo_count
        FROM projects p
        LEFT JOIN todo_projects tp ON p.id = tp.project_id
        GROUP BY p.id
        ORDER BY todo_count DESC, p.name
    ]]
    
    return query_data(query)
end

-- Get todos by tag
function M.get_todos_by_tag(tag)
    local query = [[
        SELECT t.id, t.content, t.created_at, t.completed_at, t.status, t.priority, t.due_date, t.notes
        FROM todos t
        JOIN todo_tags tt ON t.id = tt.todo_id
        JOIN tags tg ON tt.tag_id = tg.id
        WHERE tg.name = ?
        ORDER BY 
            CASE WHEN t.status = 'active' THEN 0 ELSE 1 END,
            CASE WHEN t.status = 'active' THEN 
                CASE WHEN t.due_date = '' THEN 1 ELSE 0 END
            ELSE 0 END,
            CASE WHEN t.status = 'active' THEN 
                CASE WHEN t.due_date = '' THEN t.priority ELSE t.due_date END
            ELSE t.completed_at END DESC
    ]]
    
    return query_data(query, {tag})
end

-- Get todos by project
function M.get_todos_by_project(project)
    local query = [[
        SELECT t.id, t.content, t.created_at, t.completed_at, t.status, t.priority, t.due_date, t.notes
        FROM todos t
        JOIN todo_projects tp ON t.id = tp.todo_id
        JOIN projects p ON tp.project_id = p.id
        WHERE p.name = ?
        ORDER BY 
            CASE WHEN t.status = 'active' THEN 0 ELSE 1 END,
            CASE WHEN t.status = 'active' THEN 
                CASE WHEN t.due_date = '' THEN 1 ELSE 0 END
            ELSE 0 END,
            CASE WHEN t.status = 'active' THEN 
                CASE WHEN t.due_date = '' THEN t.priority ELSE t.due_date END
            ELSE t.completed_at END DESC
    ]]
    
    return query_data(query, {project})
end

-- Get tags for a todo
function M.get_todo_tags(todo_id)
    local query = [[
        SELECT t.id, t.name
        FROM tags t
        JOIN todo_tags tt ON t.id = tt.tag_id
        WHERE tt.todo_id = ?
        ORDER BY t.name
    ]]
    
    return query_data(query, {todo_id})
end

-- Search todos
function M.search_todos(search_term)
    local query = [[
        SELECT id, content, created_at, completed_at, status, priority, due_date, notes
        FROM todos
        WHERE content LIKE ?
        ORDER BY 
            CASE WHEN status = 'active' THEN 0 ELSE 1 END,
            CASE WHEN status = 'active' THEN created_at ELSE completed_at END DESC
    ]]
    
    return query_data(query, {'%' .. search_term .. '%'})
end

-- Calculate statistics and store in the database
function M.calculate_statistics()
    -- Query to get counts
    local counts_query = [[
        SELECT 
            (SELECT COUNT(*) FROM todos) as total_count,
            (SELECT COUNT(*) FROM todos WHERE status = 'active') as active_count,
            (SELECT COUNT(*) FROM todos WHERE status = 'completed') as completed_count,
            (SELECT COUNT(*) FROM tags) as tag_count,
            (SELECT COUNT(*) FROM projects) as project_count
    ]]
    
    -- Query to get today's completions
    local today_query = [[
        SELECT COUNT(*) as today_completed
        FROM todos
        WHERE status = 'completed' 
        AND date(completed_at) = date('now', 'localtime')
    ]]
    
    -- Query to get this week's completions
    local week_query = [[
        SELECT COUNT(*) as week_completed
        FROM todos
        WHERE status = 'completed' 
        AND date(completed_at) >= date('now', 'weekday 0', '-7 days', 'localtime')
        AND date(completed_at) <= date('now', 'localtime')
    ]]
    
    -- Query to get completion times
    local completion_times_query = [[
        SELECT 
            julianday(completed_at) - julianday(created_at) AS completion_time_days
        FROM todos
        WHERE status = 'completed'
    ]]
    
    -- Get basic counts
    local counts = query_data(counts_query)[1]
    
    -- Get today's completions
    local today_completed = query_data(today_query)[1].today_completed
    
    -- Get this week's completions
    local week_completed = query_data(week_query)[1].week_completed
    
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
    
    -- Save all stats to the database
    local timestamp = utils.generate_timestamp()
    local config = get_config().get()
    local db = sqlite.open(config.db_path)
    
    if not db then
        return {
            total_count = counts.total_count,
            active_count = counts.active_count,
            completed_count = counts.completed_count,
            tag_count = counts.tag_count,
            project_count = counts.project_count,
            today_completed = today_completed,
            week_completed = week_completed,
            completion_rate = completion_rate,
            avg_completion_time = avg_completion_time,
            std_dev_completion_time = std_dev_completion_time
        }
    end
    
    -- Start transaction
    db:exec("BEGIN TRANSACTION;")
    
    local function update_stat(metric, value)
        local stmt = db:prepare([[
            INSERT OR REPLACE INTO statistics (id, metric, value, updated_at)
            SELECT 
                (SELECT id FROM statistics WHERE metric = ?), 
                ?, ?, ?
        ]])
        
        if stmt then
            stmt:bind(1, metric)
            stmt:bind(2, metric)
            stmt:bind(3, value)
            stmt:bind(4, timestamp)
            stmt:step()
            stmt:finalize()
        end
    end
    
    update_stat("total_count", counts.total_count)
    update_stat("active_count", counts.active_count)
    update_stat("completed_count", counts.completed_count)
    update_stat("tag_count", counts.tag_count)
    update_stat("project_count", counts.project_count)
    update_stat("today_completed", today_completed)
    update_stat("week_completed", week_completed)
    update_stat("completion_rate", completion_rate)
    update_stat("avg_completion_time", avg_completion_time)
    update_stat("std_dev_completion_time", std_dev_completion_time)
    
    -- Commit transaction
    db:exec("COMMIT;")
    db:close()
    
    return {
        total_count = counts.total_count,
        active_count = counts.active_count,
        completed_count = counts.completed_count,
        tag_count = counts.tag_count,
        project_count = counts.project_count,
        today_completed = today_completed,
        week_completed = week_completed,
        completion_rate = completion_rate,
        avg_completion_time = avg_completion_time,
        std_dev_completion_time = std_dev_completion_time
    }
end

-- Get saved statistics
function M.get_statistics()
    local query = [[
        SELECT metric, value
        FROM statistics
        ORDER BY metric
    ]]
    
    local rows = query_data(query)
    
    local stats = {}
    for _, row in ipairs(rows) do
        stats[row.metric] = row.value
    end
    
    -- If we have no stats, calculate them
    if vim.tbl_isempty(stats) then
        return M.calculate_statistics()
    end
    
    return stats
end

return M
