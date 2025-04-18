local M = {}

-- Format a date string
function M.format_date(date_str)
    if not date_str then
        return nil
    end
    
    -- Check if in YYYY-MM-DD format
    local year, month, day = date_str:match("(%d%d%d%d)%-(%d%d)%-(%d%d)")
    if year and month and day then
        return string.format("%s-%s-%s", year, month, day)
    end
    
    return date_str
end

-- Get today's date in YYYY-MM-DD format
function M.today()
    return os.date("%Y-%m-%d")
end

-- Check if a date is in the past
function M.is_date_past(date_str)
    if not date_str then
        return false
    end
    
    local year, month, day = date_str:match("(%d%d%d%d)%-(%d%d)%-(%d%d)")
    if not (year and month and day) then
        return false
    end
    
    local date = os.time({year = tonumber(year), month = tonumber(month), day = tonumber(day)})
    local today = os.time({year = tonumber(os.date("%Y")), month = tonumber(os.date("%m")), day = tonumber(os.date("%d"))})
    
    return date < today
end

-- Get a list of all tags from a todo text
function M.extract_tags(text)
    local tags = {}
    for tag in text:gmatch("#([%w_-]+)") do
        table.insert(tags, tag)
    end
    return tags
end

-- Get the project from a todo text
function M.extract_project(text)
    return text:match("@([%w_-]+)")
end

-- Get the due date from a todo text
function M.extract_due_date(text)
    return text:match("due:(%d%d%d%d%-%d%d%-%d%d)")
end

-- Get the priority level from a todo text
function M.extract_priority(text)
    local priority_pattern = "^(!+)%s+"
    local priority_match = text:match(priority_pattern)
    
    if priority_match then
        return #priority_match -- 1 for medium, 2 for high
    end
    
    return 0 -- Normal priority
end

-- Clean up a todo text by removing metadata
function M.clean_todo_text(text)
    -- Remove priority markers
    local cleaned = text:gsub("^(!+)%s+", "")
    
    -- We don't remove tags, projects or due dates as they are part of the text
    -- Users may want to see them in the cleaned text as well
    
    return cleaned
end

return M
