local M = {}
local utils = require('todo.utils')
local config_module = require('todo.config')
local files_module = require('todo.files')

-- Import the database module
local db = require('todo.db')

-- Function to create a directory
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

-- Parse todo items from markdown files
local function parse_todos_from_markdown(content, is_completed)
    local todos = {}
    
    if not content then
        return todos
    end
    
    local pattern
    if is_completed then
        pattern = "^%- %[x%] (.-)%s*%(Created: (%d+-%d+-%d+ %d+:%d+:%d+)%)%s*%(Completed: (%d+-%d+-%d+ %d+:%d+:%d+)%)"
    else
        pattern = "^%- %[ %] (.-)%s*%(Created: (%d+-%d+-%d+ %d+:%d+:%d+)%)"
    end
    
    for line in content:gmatch("[^\r\n]+") do
        if is_completed then
            local todo_text, created_at, completed_at = line:match(pattern)
            if todo_text and created_at and completed_at then
                table.insert(todos, {
                    content = todo_text,
                    created_at = created_at,
                    completed_at = completed_at,
                    status = "completed"
                })
            end
        else
            local todo_text, created_at = line:match(pattern)
            if todo_text and created_at then
                table.insert(todos, {
                    content = todo_text,
                    created_at = created_at,
                    status = "active"
                })
            end
        end
    end
    
    return todos
end

-- Migrate todos from markdown files to the database
function M.migrate_to_db(todo_dir, active_file, completed_file, db_path)
    -- Ensure the database is set up
    if not db.setup({db_path = db_path}) then
        vim.notify("Failed to set up database", vim.log.levels.ERROR)
        return false
    end
    
    -- Read active todos file
    local active_path = todo_dir .. "/" .. active_file
    local active_content = read_file(active_path)
    local active_todos = parse_todos_from_markdown(active_content, false)
    
    -- Read completed todos file
    local completed_path = todo_dir .. "/" .. completed_file
    local completed_content = read_file(completed_path)
    local completed_todos = parse_todos_from_markdown(completed_content, true)
    
    -- Insert active todos into the database
    for _, todo in ipairs(active_todos) do
        local query = [[
            INSERT INTO todos (content, created_at, status)
            VALUES (?, ?, ?);
        ]]
        
        local db_connection = require('lsqlite3').open(db_path)
        if not db_connection then
            vim.notify("Failed to open database", vim.log.levels.ERROR)
            return false
        end
        
        local stmt = db_connection:prepare(query)
        if not stmt then
            vim.notify("Failed to prepare statement: " .. query, vim.log.levels.ERROR)
            db_connection:close()
            return false
        end
        
        stmt:bind(1, todo.content)
        stmt:bind(2, todo.created_at)
        stmt:bind(3, todo.status)
        
        stmt:step()
        stmt:finalize()
        db_connection:close()
    end
    
    -- Insert completed todos into the database
    for _, todo in ipairs(completed_todos) do
        local query = [[
            INSERT INTO todos (content, created_at, completed_at, status)
            VALUES (?, ?, ?, ?);
        ]]
        
        local db_connection = require('lsqlite3').open(db_path)
        if not db_connection then
            vim.notify("Failed to open database", vim.log.levels.ERROR)
            return false
        end
        
        local stmt = db_connection:prepare(query)
        if not stmt then
            vim.notify("Failed to prepare statement: " .. query, vim.log.levels.ERROR)
            db_connection:close()
            return false
        end
        
        stmt:bind(1, todo.content)
        stmt:bind(2, todo.created_at)
        stmt:bind(3, todo.completed_at)
        stmt:bind(4, todo.status)
        
        stmt:step()
        stmt:finalize()
        db_connection:close()
    end
    
    -- Calculate and update statistics
    db.calculate_statistics()
    
    -- Create backup of original files
    local backup_dir = todo_dir .. "/backup_" .. os.date("%Y%m%d%H%M%S")
    if create_directory(backup_dir) then
        local backup_active = backup_dir .. "/" .. active_file
        local backup_completed = backup_dir .. "/" .. completed_file
        
        -- Copy files to backup
        local success_active = os.execute(string.format('cp "%s" "%s"', active_path, backup_active))
        local success_completed = os.execute(string.format('cp "%s" "%s"', completed_path, backup_completed))
        
        if success_active and success_completed then
            vim.notify("Original files backed up to: " .. backup_dir, vim.log.levels.INFO)
        else
            vim.notify("Failed to backup original files", vim.log.levels.WARN)
        end
    end
    
    return true
end

-- Export todos from database to files
function M.export_from_db(db_path)
    local has_sqlite, sqlite = pcall(require, 'lsqlite3')
    if not has_sqlite then
        vim.notify("SQLite3 not found. Cannot export from database.", vim.log.levels.ERROR)
        return false
    end
    
    local config = config_module.get()
    local active_path = config.get_active_todo_path()
    local completed_path = config.get_completed_todo_path()
    
    -- Open database
    local db = sqlite.open(db_path)
    if not db then
        vim.notify("Failed to open database: " .. db_path, vim.log.levels.ERROR)
        return false
    end
    
    -- Query active todos
    local active_todos = {}
    local active_stmt = db:prepare([[
        SELECT content, created_at
        FROM todos
        WHERE status = 'active'
        ORDER BY created_at DESC
    ]])
    
    while active_stmt:step() == sqlite.ROW do
        table.insert(active_todos, {
            content = active_stmt:column_value(0),
            created_at = active_stmt:column_value(1)
        })
    end
    active_stmt:finalize()
    
    -- Query completed todos
    local completed_todos = {}
    local completed_stmt = db:prepare([[
        SELECT content, created_at, completed_at
        FROM todos
        WHERE status = 'completed'
        ORDER BY completed_at DESC
    ]])
    
    while completed_stmt:step() == sqlite.ROW do
        table.insert(completed_todos, {
            content = completed_stmt:column_value(0),
            created_at = completed_stmt:column_value(1),
            completed_at = completed_stmt:column_value(2)
        })
    end
    completed_stmt:finalize()
    db:close()
    
    -- Create active todos markdown
    local active_content = "# Active Todos\n## Tasks\n\n"
    for _, todo in ipairs(active_todos) do
        active_content = active_content .. string.format("- [ ] %s (Created: %s)\n", 
            todo.content, todo.created_at)
    end
    
    -- Create completed todos markdown
    local completed_content = "# Completed Todos\n## History\n\n"
    for _, todo in ipairs(completed_todos) do
        completed_content = completed_content .. string.format("- [x] %s (Created: %s) (Completed: %s)\n", 
            todo.content, todo.created_at, todo.completed_at)
    end
    
    -- Write to files
    local success = utils.write_to_file(active_path, active_content, "w")
    if not success then
        vim.notify("Failed to write active todos to file", vim.log.levels.ERROR)
        return false
    end
    
    success = utils.write_to_file(completed_path, completed_content, "w")
    if not success then
        vim.notify("Failed to write completed todos to file", vim.log.levels.ERROR)
        return false
    end
    
    vim.notify("Todos exported to files successfully", vim.log.levels.INFO)
    return true
end

-- Import todos from files to database
function M.import_to_db(db_path)
    local has_sqlite, sqlite = pcall(require, 'lsqlite3')
    if not has_sqlite then
        vim.notify("SQLite3 not found. Cannot import to database.", vim.log.levels.ERROR)
        return false
    end
    
    local config = config_module.get()
    local active_path = config.get_active_todo_path()
    local completed_path = config.get_completed_todo_path()
    
    -- Check if files exist
    if not utils.file_exists(active_path) and not utils.file_exists(completed_path) then
        vim.notify("No todo files found to import", vim.log.levels.WARN)
        return false
    end
    
    -- Open database
    local db = sqlite.open(db_path)
    if not db then
        vim.notify("Failed to open database: " .. db_path, vim.log.levels.ERROR)
        return false
    end
    
    -- Start transaction
    db:exec("BEGIN TRANSACTION;")
    
    -- Parse active todos
    if utils.file_exists(active_path) then
        local active_todos = files_module.parse_todos(active_path)
        
        -- Insert active todos into database
        local active_stmt = db:prepare([[
            INSERT INTO todos (content, created_at, status)
            VALUES (?, ?, 'active');
        ]])
        
        for _, todo in ipairs(active_todos) do
            active_stmt:reset()
            active_stmt:bind(1, todo.content)
            active_stmt:bind(2, todo.created_at or utils.generate_timestamp())
            
            if active_stmt:step() ~= sqlite.DONE then
                vim.notify("Failed to import active todo: " .. todo.content, vim.log.levels.ERROR)
                db:exec("ROLLBACK;")
                db:close()
                return false
            end
        end
        
        active_stmt:finalize()
    end
    
    -- Parse completed todos
    if utils.file_exists(completed_path) then
        local completed_todos = files_module.parse_todos(completed_path)
        
        -- Insert completed todos into database
        local completed_stmt = db:prepare([[
            INSERT INTO todos (content, created_at, completed_at, status)
            VALUES (?, ?, ?, 'completed');
        ]])
        
        for _, todo in ipairs(completed_todos) do
            completed_stmt:reset()
            completed_stmt:bind(1, todo.content)
            completed_stmt:bind(2, todo.created_at or utils.generate_timestamp())
            completed_stmt:bind(3, todo.completed_at or utils.generate_timestamp())
            
            if completed_stmt:step() ~= sqlite.DONE then
                vim.notify("Failed to import completed todo: " .. todo.content, vim.log.levels.ERROR)
                db:exec("ROLLBACK;")
                db:close()
                return false
            end
        end
        
        completed_stmt:finalize()
    end
    
    -- Commit transaction
    db:exec("COMMIT;")
    db:close()
    
    vim.notify("Todos imported to database successfully", vim.log.levels.INFO)
    return true
end

-- Check if migration is needed and perform it
function M.check_and_migrate()
    local config = config_module.get()
    local state = config_module.get_state()
    
    -- Skip if already migrated or auto_migrate is disabled
    if state.migration_complete or not config.auto_migrate then
        return
    end
    
    -- Check if we should migrate to database
    if config.use_database and config.view_mode == "database" then
        -- Check if files exist
        local active_path = config.get_active_todo_path()
        local completed_path = config.get_completed_todo_path()
        
        if utils.file_exists(active_path) or utils.file_exists(completed_path) then
            vim.notify("Migrating todos from files to database...", vim.log.levels.INFO)
            local success = M.import_to_db(config.db_path)
            
            if success then
                config_module.update_state("migration_complete", true)
                vim.notify("Migration complete", vim.log.levels.INFO)
            end
        else
            -- No files to migrate, just mark as complete
            config_module.update_state("migration_complete", true)
        end
    end
end

-- Toggle view mode between database and files
function M.toggle_view_mode()
    local config = config_module.get()
    
    if config.view_mode == "database" then
        config_module.set_value("view_mode", "files")
        -- Export from database to files
        M.export_from_db(config.db_path)
        vim.notify("Switched to file view mode", vim.log.levels.INFO)
    else
        config_module.set_value("view_mode", "database")
        -- Import from files to database
        M.import_to_db(config.db_path)
        vim.notify("Switched to database view mode", vim.log.levels.INFO)
    end
end

return M
