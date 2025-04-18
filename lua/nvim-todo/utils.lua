local M = {}

-- Generate a timestamp in the format YYYY-MM-DD HH:MM:SS
function M.generate_timestamp()
    return os.date("%Y-%m-%d %H:%M:%S")
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

-- Write content to a file, ensuring file exists and is writable
function M.write_to_file(path, content, mode)
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
function M.read_file(path)
    local file = io.open(path, "r")
    if file then
        local content = file:read("*all")
        file:close()
        return content
    end
    return nil
end

-- Check if a file exists
function M.file_exists(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        return true
    end
    return false
end

-- Extract tags from a todo text (e.g., "Do something #tag1 #tag2")
function M.extract_tags(todo_text)
    local tags = {}
    for tag in todo_text:gmatch("#(%w+)") do
        table.insert(tags, tag)
    end
    return tags
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