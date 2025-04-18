local M = {}
local has_sqlite, sqlite = pcall(require, "sqlite")
local db = nil

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

-- Initialize the database
function M.init(db_path)
    if not has_sqlite then
        vim.notify("SQLite is required for todo.nvim. Please install the sqlite.lua dependency.", vim.log.levels.ERROR)
        return false
    end
    
    db = sqlite.new(db_path)
    
    -- Create tables if they don't exist
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
    
    return true
end

-- Add a new todo
function M.add_todo(text)
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
    if not db then return false end
    
    db:delete("todos", {
        id = id
    })
    
    return true
end

-- Update a todo
function M.update_todo(id, text)
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
