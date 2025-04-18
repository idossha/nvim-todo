local M = {}
local has_sqlite = false
local sqlite = nil
local db = nil
local use_fallback = false
local fallback_data = {
    todos = {},
    tags = {},
    next_id = 1
}
local fallback_file = nil

-- Try to load SQLite
local function try_load_sqlite()
    has_sqlite, sqlite = pcall(require, "sqlite.db")
    if not has_sqlite then
        has_sqlite, sqlite = pcall(require, "sqlite")
    end
    return has_sqlite
end

-- Helper function to parse todo metadata
local function parse_todo(text)
    local todo = {
        text = text,
        priority = 0,   -- 0: normal, 1: medium, 2: high
        tags = {},
        project = nil,
        due_date = nil
    }
    
    -- Check for priority (!: medium, !!: high)
    local priority_pattern = "^(!+)%s+"
    local priority_match = text:match(priority_pattern)
    if priority_match then
        todo.priority = #priority_match
        todo.text = text:gsub(priority_pattern, "")
    end
    
    -- Extract tags (#tag)
    for tag in todo.text:gmatch("#([%w_-]+)") do
        table.insert(todo.tags, tag)
    end
    
    -- Extract project (@project)
    todo.project = todo.text:match("@([%w_-]+)")
    
    -- Extract due date (due:YYYY-MM-DD)
    todo.due_date = todo.text:match("due:(%d%d%d%d%-%d%d%-%d%d)")
    
    return todo
end

-- Save fallback data to file
local function save_fallback_data()
    if not fallback_file then return end
    
    local file = io.open(fallback_file, "w")
    if not file then return end
    
    file:write(vim.fn.json_encode(fallback_data))
    file:close()
end

-- Load fallback data from file
local function load_fallback_data()
    if not fallback_file then return end
    
    local file = io.open(fallback_file, "r")
    if not file then return end
    
    local content = file:read("*all")
    file:close()
    
    if content and content ~= "" then
        local ok, data = pcall(vim.fn.json_decode, content)
        if ok and data then
            fallback_data = data
        end
    end
end

-- Initialize the database
function M.init(db_path)
    -- Try to load SQLite
    if try_load_sqlite() then
        -- Using SQLite database
        use_fallback = false
        
        -- Create the database connection
        local ok, connection = pcall(function()
            return sqlite.new(db_path)
        end)
        
        if not ok or not connection then
            vim.notify("Failed to connect to SQLite database. Falling back to file storage.", vim.log.levels.WARN)
            use_fallback = true
        else
            db = connection
            
            -- Create tables if they don't exist
            local exec_ok, err = pcall(function()
                db:exec([[
                    CREATE TABLE IF NOT EXISTS todos (
                        id INTEGER PRIMARY KEY,
                        text TEXT NOT NULL,
                        priority INTEGER DEFAULT 0,
                        project TEXT,
                        due_date TEXT,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        completed_at TIMESTAMP,
                        is_completed BOOLEAN DEFAULT 0
                    );
                    
                    CREATE TABLE IF NOT EXISTS tags (
                        todo_id INTEGER,
                        tag TEXT,
                        PRIMARY KEY (todo_id, tag),
                        FOREIGN KEY (todo_id) REFERENCES todos (id) ON DELETE CASCADE
                    );
                ]])
            end)
            
            if not exec_ok then
                vim.notify("Failed to create database tables: " .. tostring(err) .. ". Falling back to file storage.", vim.log.levels.WARN)
                use_fallback = true
            end
        end
    else
        -- Fallback to file-based storage
        vim.notify("SQLite not available. Using file-based storage instead.", vim.log.levels.WARN)
        use_fallback = true
    end
    
    -- Configure fallback storage if needed
    if use_fallback then
        -- Use a JSON file in the same directory as the DB
        fallback_file = vim.fn.fnamemodify(db_path, ":r") .. ".json"
        load_fallback_data()
    end
    
    return true
end

-- Fallback functions for file-based storage
local function fallback_add_todo(text)
    local todo = parse_todo(text)
    local id = fallback_data.next_id
    
    -- Prepare todo object
    local todo_obj = {
        id = id,
        text = todo.text,
        priority = todo.priority,
        project = todo.project,
        due_date = todo.due_date,
        created_at = os.date("%Y-%m-%d %H:%M:%S"),
        completed_at = nil,
        is_completed = 0,
        tags = todo.tags
    }
    
    -- Add todo to fallback data
    table.insert(fallback_data.todos, todo_obj)
    
    -- Store tags
    for _, tag in ipairs(todo.tags) do
        table.insert(fallback_data.tags, {
            todo_id = id,
            tag = tag
        })
    end
    
    -- Increment ID counter
    fallback_data.next_id = fallback_data.next_id + 1
    
    -- Save to file
    save_fallback_data()
    
    return id
end

local function fallback_complete_todo(id)
    -- Find todo by ID
    for _, todo in ipairs(fallback_data.todos) do
        if todo.id == id then
            todo.is_completed = 1
            todo.completed_at = os.date("%Y-%m-%d %H:%M:%S")
            save_fallback_data()
            return true
        end
    end
    
    return false
end

local function fallback_delete_todo(id)
    -- Find todo by ID
    for i, todo in ipairs(fallback_data.todos) do
        if todo.id == id then
            table.remove(fallback_data.todos, i)
            
            -- Remove tags
            local i = 1
            while i <= #fallback_data.tags do
                if fallback_data.tags[i].todo_id == id then
                    table.remove(fallback_data.tags, i)
                else
                    i = i + 1
                end
            end
            
            save_fallback_data()
            return true
        end
    end
    
    return false
end

local function fallback_update_todo(id, text)
    local todo_data = parse_todo(text)
    
    -- Find todo by ID
    for _, todo in ipairs(fallback_data.todos) do
        if todo.id == id then
            todo.text = todo_data.text
            todo.priority = todo_data.priority
            todo.project = todo_data.project
            todo.due_date = todo_data.due_date
            
            -- Remove old tags
            local i = 1
            while i <= #fallback_data.tags do
                if fallback_data.tags[i].todo_id == id then
                    table.remove(fallback_data.tags, i)
                else
                    i = i + 1
                end
            end
            
            -- Add new tags
            for _, tag in ipairs(todo_data.tags) do
                table.insert(fallback_data.tags, {
                    todo_id = id,
                    tag = tag
                })
            end
            
            todo.tags = todo_data.tags
            
            save_fallback_data()
            return true
        end
    end
    
    return false
end

local function fallback_get_active_todos()
    local todos = {}
    
    for _, todo in ipairs(fallback_data.todos) do
        if todo.is_completed == 0 then
            table.insert(todos, vim.deepcopy(todo))
        end
    end
    
    -- Sort by priority (desc) and due date (asc)
    table.sort(todos, function(a, b)
        if a.priority ~= b.priority then
            return a.priority > b.priority
        end
        
        if a.due_date and b.due_date then
            return a.due_date < b.due_date
        elseif a.due_date then
            return true
        elseif b.due_date then
            return false
        end
        
        return false
    end)
    
    return todos
end

local function fallback_get_completed_todos()
    local todos = {}
    
    for _, todo in ipairs(fallback_data.todos) do
        if todo.is_completed == 1 then
            table.insert(todos, vim.deepcopy(todo))
        end
    end
    
    -- Sort by completion date (desc)
    table.sort(todos, function(a, b)
        if a.completed_at and b.completed_at then
            return a.completed_at > b.completed_at
        elseif a.completed_at then
            return true
        elseif b.completed_at then
            return false
        end
        
        return false
    end)
    
    return todos
end

local function is_date_before(date1, date2)
    -- Parse dates (YYYY-MM-DD)
    local y1, m1, d1 = date1:match("(%d+)-(%d+)-(%d+)")
    local y2, m2, d2 = date2:match("(%d+)-(%d+)-(%d+)")
    
    if not (y1 and m1 and d1 and y2 and m2 and d2) then
        return false
    end
    
    y1, m1, d1 = tonumber(y1), tonumber(m1), tonumber(d1)
    y2, m2, d2 = tonumber(y2), tonumber(m2), tonumber(d2)
    
    if y1 < y2 then return true end
    if y1 > y2 then return false end
    if m1 < m2 then return true end
    if m1 > m2 then return false end
    return d1 < d2
end

local function fallback_get_overdue_todos()
    local todos = {}
    local today = os.date("%Y-%m-%d")
    
    for _, todo in ipairs(fallback_data.todos) do
        if todo.is_completed == 0 and todo.due_date and is_date_before(todo.due_date, today) then
            table.insert(todos, vim.deepcopy(todo))
        end
    end
    
    -- Sort by due date (asc)
    table.sort(todos, function(a, b)
        return is_date_before(a.due_date, b.due_date)
    end)
    
    return todos
end

local function fallback_get_today_todos()
    local todos = {}
    local today = os.date("%Y-%m-%d")
    
    for _, todo in ipairs(fallback_data.todos) do
        if todo.is_completed == 0 and todo.due_date == today then
            table.insert(todos, vim.deepcopy(todo))
        end
    end
    
    -- Sort by priority (desc)
    table.sort(todos, function(a, b)
        return a.priority > b.priority
    end)
    
    return todos
end

local function fallback_get_stats()
    local stats = {
        active = 0,
        completed = 0,
        completed_today = 0,
        overdue = 0,
        due_today = 0,
        projects = {},
        tags = {}
    }
    
    local today = os.date("%Y-%m-%d")
    local projects_map = {}
    local tags_map = {}
    
    for _, todo in ipairs(fallback_data.todos) do
        if todo.is_completed == 0 then
            stats.active = stats.active + 1
            
            if todo.due_date and is_date_before(todo.due_date, today) then
                stats.overdue = stats.overdue + 1
            elseif todo.due_date == today then
                stats.due_today = stats.due_today + 1
            end
        else
            stats.completed = stats.completed + 1
            if todo.completed_at and todo.completed_at:match("^" .. today) then
                stats.completed_today = stats.completed_today + 1
            end
        end
        
        if todo.project and not projects_map[todo.project] then
            projects_map[todo.project] = true
            table.insert(stats.projects, todo.project)
        end
        
        if todo.tags then
            for _, tag in ipairs(todo.tags) do
                if not tags_map[tag] then
                    tags_map[tag] = true
                    table.insert(stats.tags, tag)
                end
            end
        end
    end
    
    return stats
end

local function fallback_filter_by_tag(tag)
    local todos = {}
    
    for _, todo in ipairs(fallback_data.todos) do
        if todo.is_completed == 0 and todo.tags then
            for _, todo_tag in ipairs(todo.tags) do
                if todo_tag == tag then
                    table.insert(todos, vim.deepcopy(todo))
                    break
                end
            end
        end
    end
    
    -- Sort by priority (desc) and due date (asc)
    table.sort(todos, function(a, b)
        if a.priority ~= b.priority then
            return a.priority > b.priority
        end
        
        if a.due_date and b.due_date then
            return a.due_date < b.due_date
        elseif a.due_date then
            return true
        elseif b.due_date then
            return false
        end
        
        return false
    end)
    
    return todos
end

local function fallback_filter_by_project(project)
    local todos = {}
    
    for _, todo in ipairs(fallback_data.todos) do
        if todo.is_completed == 0 and todo.project == project then
            table.insert(todos, vim.deepcopy(todo))
        end
    end
    
    -- Sort by priority (desc) and due date (asc)
    table.sort(todos, function(a, b)
        if a.priority ~= b.priority then
            return a.priority > b.priority
        end
        
        if a.due_date and b.due_date then
            return a.due_date < b.due_date
        elseif a.due_date then
            return true
        elseif b.due_date then
            return false
        end
        
        return false
    end)
    
    return todos
end

local function fallback_search_todos(query)
    local todos = {}
    query = query:lower()
    
    for _, todo in ipairs(fallback_data.todos) do
        if todo.is_completed == 0 and todo.text:lower():find(query, 1, true) then
            table.insert(todos, vim.deepcopy(todo))
        end
    end
    
    -- Sort by priority (desc) and due date (asc)
    table.sort(todos, function(a, b)
        if a.priority ~= b.priority then
            return a.priority > b.priority
        end
        
        if a.due_date and b.due_date then
            return a.due_date < b.due_date
        elseif a.due_date then
            return true
        elseif b.due_date then
            return false
        end
        
        return false
    end)
    
    return todos
end

-- Add a new todo
function M.add_todo(text)
    if use_fallback then
        return fallback_add_todo(text)
    end
    
    if not db then return nil end
    
    local todo = parse_todo(text)
    
    -- Insert the todo
    local id = db:insert("todos", {
        text = todo.text,
        priority = todo.priority,
        project = todo.project,
        due_date = todo.due_date
    })
    
    -- Insert tags
    for _, tag in ipairs(todo.tags) do
        db:insert("tags", {
            todo_id = id,
            tag = tag
        })
    end
    
    return id
end

-- Complete a todo
function M.complete_todo(id)
    if use_fallback then
        return fallback_complete_todo(id)
    end
    
    if not db then return false end
    
    db:update("todos", {
        is_completed = 1,
        completed_at = os.date("%Y-%m-%d %H:%M:%S")
    }, {
        id = id
    })
    
    return true
end

-- Delete a todo
function M.delete_todo(id)
    if use_fallback then
        return fallback_delete_todo(id)
    end
    
    if not db then return false end
    
    db:delete("todos", {
        id = id
    })
    
    return true
end

-- Update a todo
function M.update_todo(id, text)
    if use_fallback then
        return fallback_update_todo(id, text)
    end
    
    if not db then return false end
    
    local todo = parse_todo(text)
    
    -- Update the todo
    db:update("todos", {
        text = todo.text,
        priority = todo.priority,
        project = todo.project,
        due_date = todo.due_date
    }, {
        id = id
    })
    
    -- Delete existing tags
    db:delete("tags", {
        todo_id = id
    })
    
    -- Insert new tags
    for _, tag in ipairs(todo.tags) do
        db:insert("tags", {
            todo_id = id,
            tag = tag
        })
    end
    
    return true
end

-- Get all active todos
function M.get_active_todos()
    if use_fallback then
        return fallback_get_active_todos()
    end
    
    if not db then return {} end
    
    local todos = db:select("SELECT * FROM todos WHERE is_completed = 0 ORDER BY priority DESC, due_date ASC")
    
    -- Load tags for each todo
    for _, todo in ipairs(todos) do
        local tags = db:select("SELECT tag FROM tags WHERE todo_id = ?", todo.id)
        todo.tags = {}
        for _, tag_row in ipairs(tags) do
            table.insert(todo.tags, tag_row.tag)
        end
    end
    
    return todos
end

-- Get all completed todos
function M.get_completed_todos()
    if use_fallback then
        return fallback_get_completed_todos()
    end
    
    if not db then return {} end
    
    local todos = db:select("SELECT * FROM todos WHERE is_completed = 1 ORDER BY completed_at DESC")
    
    -- Load tags for each todo
    for _, todo in ipairs(todos) do
        local tags = db:select("SELECT tag FROM tags WHERE todo_id = ?", todo.id)
        todo.tags = {}
        for _, tag_row in ipairs(tags) do
            table.insert(todo.tags, tag_row.tag)
        end
    end
    
    return todos
end

-- Get overdue todos
function M.get_overdue_todos()
    if use_fallback then
        return fallback_get_overdue_todos()
    end
    
    if not db then return {} end
    
    local todos = db:select([[
        SELECT * FROM todos 
        WHERE is_completed = 0 
          AND due_date < date('now') 
          AND due_date IS NOT NULL
        ORDER BY due_date ASC
    ]])
    
    -- Load tags for each todo
    for _, todo in ipairs(todos) do
        local tags = db:select("SELECT tag FROM tags WHERE todo_id = ?", todo.id)
        todo.tags = {}
        for _, tag_row in ipairs(tags) do
            table.insert(todo.tags, tag_row.tag)
        end
    end
    
    return todos
end

-- Get todos due today
function M.get_today_todos()
    if use_fallback then
        return fallback_get_today_todos()
    end
    
    if not db then return {} end
    
    local todos = db:select([[
        SELECT * FROM todos 
        WHERE is_completed = 0 
          AND due_date = date('now')
        ORDER BY priority DESC
    ]])
    
    -- Load tags for each todo
    for _, todo in ipairs(todos) do
        local tags = db:select("SELECT tag FROM tags WHERE todo_id = ?", todo.id)
        todo.tags = {}
        for _, tag_row in ipairs(tags) do
            table.insert(todo.tags, tag_row.tag)
        end
    end
    
    return todos
end

-- Get statistics
function M.get_stats()
    if use_fallback then
        return fallback_get_stats()
    end
    
    if not db then return {} end
    
    local stats = {}
    
    -- Total active todos
    local active = db:eval("SELECT COUNT(*) FROM todos WHERE is_completed = 0")
    stats.active = active
    
    -- Total completed todos
    local completed = db:eval("SELECT COUNT(*) FROM todos WHERE is_completed = 1")
    stats.completed = completed
    
    -- Todos completed today
    local completed_today = db:eval("SELECT COUNT(*) FROM todos WHERE is_completed = 1 AND date(completed_at) = date('now')")
    stats.completed_today = completed_today
    
    -- Overdue todos
    local overdue = db:eval("SELECT COUNT(*) FROM todos WHERE is_completed = 0 AND due_date < date('now') AND due_date IS NOT NULL")
    stats.overdue = overdue
    
    -- Due today
    local due_today = db:eval("SELECT COUNT(*) FROM todos WHERE is_completed = 0 AND due_date = date('now')")
    stats.due_today = due_today
    
    -- Projects
    local projects = db:select("SELECT DISTINCT project FROM todos WHERE project IS NOT NULL")
    stats.projects = {}
    for _, project in ipairs(projects) do
        table.insert(stats.projects, project.project)
    end
    
    -- Tags
    local tags = db:select("SELECT DISTINCT tag FROM tags")
    stats.tags = {}
    for _, tag in ipairs(tags) do
        table.insert(stats.tags, tag.tag)
    end
    
    return stats
end

-- Filter todos by tag
function M.filter_by_tag(tag)
    if use_fallback then
        return fallback_filter_by_tag(tag)
    end
    
    if not db then return {} end
    
    local todos = db:select([[
        SELECT t.* FROM todos t
        JOIN tags tg ON t.id = tg.todo_id
        WHERE t.is_completed = 0 AND tg.tag = ?
        ORDER BY t.priority DESC, t.due_date ASC
    ]], tag)
    
    -- Load tags for each todo
    for _, todo in ipairs(todos) do
        local tags = db:select("SELECT tag FROM tags WHERE todo_id = ?", todo.id)
        todo.tags = {}
        for _, tag_row in ipairs(tags) do
            table.insert(todo.tags, tag_row.tag)
        end
    end
    
    return todos
end

-- Filter todos by project
function M.filter_by_project(project)
    if use_fallback then
        return fallback_filter_by_project(project)
    end
    
    if not db then return {} end
    
    local todos = db:select([[
        SELECT * FROM todos
        WHERE is_completed = 0 AND project = ?
        ORDER BY priority DESC, due_date ASC
    ]], project)
    
    -- Load tags for each todo
    for _, todo in ipairs(todos) do
        local tags = db:select("SELECT tag FROM tags WHERE todo_id = ?", todo.id)
        todo.tags = {}
        for _, tag_row in ipairs(tags) do
            table.insert(todo.tags, tag_row.tag)
        end
    end
    
    return todos
end

-- Search todos
function M.search_todos(query)
    if use_fallback then
        return fallback_search_todos(query)
    end
    
    if not db then return {} end
    
    local todos = db:select([[
        SELECT * FROM todos
        WHERE is_completed = 0 AND text LIKE ?
        ORDER BY priority DESC, due_date ASC
    ]], "%" .. query .. "%")
    
    -- Load tags for each todo
    for _, todo in ipairs(todos) do
        local tags = db:select("SELECT tag FROM tags WHERE todo_id = ?", todo.id)
        todo.tags = {}
        for _, tag_row in ipairs(tags) do
            table.insert(todo.tags, tag_row.tag)
        end
    end
    
    return todos
end

return M

