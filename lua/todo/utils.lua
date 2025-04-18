local M = {}

-- Generate a timestamp in the format YYYY-MM-DD HH:MM:SS
function M.generate_timestamp()
    return os.date("%Y-%m-%d %H:%M:%S")
end

-- Generate a date in the format YYYY-MM-DD
function M.generate_date()
    return os.date("%Y-%m-%d")
end

-- Create directory if it doesn't exist
function M.create_directory(path)
    local success, err = pcall(function()
        vim.fn.mkdir(path, "p")
    end)
    
    if not success then
        vim.notify("Failed to create directory: " .. path .. "\nError: " .. tostring(err), vim.log.levels.ERROR)
        return false
    end
    return true
end

-- Check if a string is nil or empty
function M.is_empty(str)
    return str == nil or str == ""
end

-- Extract tags from a todo text (e.g., "Do something #tag1 #tag2")
function M.extract_tags(todo_text)
    local tags = {}
    for tag in todo_text:gmatch("#(%w+)") do
        table.insert(tags, tag)
    end
    return tags
end

-- Extract project from a todo text (e.g., "Do something @project")
function M.extract_project(todo_text)
    return todo_text:match("@(%w+)")
end

-- Extract due date from todo text (e.g., "Do something due:2023-04-01")
function M.extract_due_date(todo_text)
    return todo_text:match("due:([%d-]+)")
end

-- Extract priority from todo text (e.g., "!high priority" or "!!critical")
function M.extract_priority(todo_text)
    if todo_text:match("^!!%s") then
        return 2, todo_text:gsub("^!!%s", "")
    elseif todo_text:match("^!%s") then
        return 1, todo_text:gsub("^!%s", "")
    else
        return 0, todo_text
    end
end

-- Parse todo text and extract metadata
function M.parse_todo(todo_text)
    local result = {
        content = todo_text,
        tags = {},
        priority = 0,
        due_date = nil,
        project = nil
    }
    
    -- Extract priority
    result.priority, result.content = M.extract_priority(result.content)
    
    -- Extract due date
    local due_date = M.extract_due_date(result.content)
    if due_date then
        result.due_date = due_date
        result.content = result.content:gsub("due:" .. due_date, ""):gsub("%s+", " ")
    end
    
    -- Extract project
    result.project = M.extract_project(result.content)
    
    -- Extract tags
    result.tags = M.extract_tags(result.content)
    
    return result
end

-- Format a date difference in a human-readable format
function M.format_relative_date(date_str)
    if not date_str or date_str == "" then
        return ""
    end
    
    local year, month, day = date_str:match("(%d+)-(%d+)-(%d+)")
    if not year or not month or not day then
        return date_str
    end
    
    local timestamp = os.time({
        year = tonumber(year),
        month = tonumber(month),
        day = tonumber(day),
        hour = 0,
        min = 0,
        sec = 0
    })
    
    local now = os.time()
    local diff = os.difftime(timestamp, now) -- Seconds difference
    
    -- If date is in the past
    if diff < 0 then
        diff = math.abs(diff)
        local days = math.floor(diff / 86400)
        
        if days == 0 then
            return "today"
        elseif days == 1 then
            return "yesterday"
        elseif days < 7 then
            return days .. " days ago"
        elseif days < 31 then
            return math.floor(days / 7) .. " weeks ago"
        elseif days < 365 then
            return math.floor(days / 30) .. " months ago"
        else
            return math.floor(days / 365) .. " years ago"
        end
    else
        -- If date is in the future
        local days = math.floor(diff / 86400)
        
        if days == 0 then
            return "today"
        elseif days == 1 then
            return "tomorrow"
        elseif days < 7 then
            return "in " .. days .. " days"
        elseif days < 31 then
            return "in " .. math.floor(days / 7) .. " weeks"
        elseif days < 365 then
            return "in " .. math.floor(days / 30) .. " months"
        else
            return "in " .. math.floor(days / 365) .. " years"
        end
    end
end

-- Check if a date string is due soon
function M.is_due_soon(date_str, days_threshold)
    days_threshold = days_threshold or 3
    
    if not date_str or date_str == "" then
        return false
    end
    
    local year, month, day = date_str:match("(%d+)-(%d+)-(%d+)")
    if not year or not month or not day then
        return false
    end
    
    local due_date = os.time({
        year = tonumber(year),
        month = tonumber(month),
        day = tonumber(day),
        hour = 23,
        min = 59,
        sec = 59
    })
    
    local now = os.time()
    local diff = os.difftime(due_date, now) -- Seconds difference
    local days = math.floor(diff / 86400)
    
    -- Return true if due date is today or within threshold days
    return days >= 0 and days <= days_threshold
end

-- Check if a date is past due
function M.is_past_due(date_str)
    if not date_str or date_str == "" then
        return false
    end
    
    local year, month, day = date_str:match("(%d+)-(%d+)-(%d+)")
    if not year or not month or not day then
        return false
    end
    
    local due_date = os.time({
        year = tonumber(year),
        month = tonumber(month),
        day = tonumber(day),
        hour = 23,
        min = 59,
        sec = 59
    })
    
    local now = os.time()
    return os.difftime(due_date, now) < 0
end

-- Get current date in YYYY-MM-DD format
function M.get_today()
    return os.date("%Y-%m-%d")
end

-- Safe table serialization
function M.serialize_table(tbl)
    if type(tbl) ~= "table" then return tostring(tbl) end
    
    local result = "{"
    for k, v in pairs(tbl) do
        -- Handle the key
        if type(k) == "string" then
            result = result .. "['" .. k .. "']="
        else
            result = result .. "[" .. tostring(k) .. "]="
        end
        
        -- Handle the value
        if type(v) == "table" then
            result = result .. M.serialize_table(v)
        elseif type(v) == "string" then
            result = result .. "'" .. v .. "'"
        else
            result = result .. tostring(v)
        end
        
        result = result .. ","
    end
    
    return result .. "}"
end

return M 