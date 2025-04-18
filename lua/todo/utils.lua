local M = {}

-- Parse a date string to a timestamp
function M.parse_date(date_string)
  if not date_string or date_string == "" then
    return nil
  end
  
  -- Try to parse YYYY-MM-DD format
  local year, month, day = date_string:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
  if year and month and day then
    return os.time({
      year = tonumber(year),
      month = tonumber(month),
      day = tonumber(day),
      hour = 0,
      min = 0,
      sec = 0
    })
  end
  
  return nil
end

-- Format a timestamp as YYYY-MM-DD
function M.format_date(timestamp)
  if not timestamp then
    return ""
  end
  
  return os.date("%Y-%m-%d", timestamp)
end

-- Check if a date is in the past (overdue)
function M.is_overdue(date_string)
  local timestamp = M.parse_date(date_string)
  if not timestamp then
    return false
  end
  
  local today = os.time({
    year = os.date("%Y"),
    month = os.date("%m"),
    day = os.date("%d"),
    hour = 0,
    min = 0,
    sec = 0
  })
  
  return timestamp < today
end

-- Get a unique ID for a buffer
function M.get_buf_id(buf)
  return "todo_" .. buf
end

-- Escape a string for use in SQL
function M.sql_escape(str)
  if not str then
    return "NULL"
  end
  
  -- Replace single quotes with two single quotes
  return "'" .. string.gsub(str, "'", "''") .. "'"
end

-- Convert a Lua table to a PostgreSQL array string
function M.to_pg_array(tbl)
  if not tbl or #tbl == 0 then
    return "{}"
  end
  
  local escaped = {}
  for _, v in ipairs(tbl) do
    table.insert(escaped, M.sql_escape(v))
  end
  
  return "{" .. table.concat(escaped, ",") .. "}"
end

-- Convert a PostgreSQL array string to a Lua table
function M.from_pg_array(arr_str)
  if not arr_str or arr_str == "{}" then
    return {}
  end
  
  -- Remove the leading '{' and trailing '}'
  local str = string.sub(arr_str, 2, -2)
  
  -- Split by commas that are not inside quotes
  local result = {}
  local current = ""
  local in_quotes = false
  
  for i = 1, #str do
    local char = string.sub(str, i, i)
    
    if char == "'" then
      in_quotes = not in_quotes
    elseif char == "," and not in_quotes then
      table.insert(result, current)
      current = ""
    else
      current = current .. char
    end
  end
  
  if current ~= "" then
    table.insert(result, current)
  end
  
  -- Remove quotes and unescape
  for i, v in ipairs(result) do
    if string.sub(v, 1, 1) == "'" and string.sub(v, -1) == "'" then
      v = string.sub(v, 2, -2)
      -- Unescape
      v = string.gsub(v, "''", "'")
    end
    result[i] = v
  end
  
  return result
end

-- Deep copy a table
function M.deep_copy(orig)
  local orig_type = type(orig)
  local copy
  if orig_type == 'table' then
    copy = {}
    for orig_key, orig_value in next, orig, nil do
      copy[M.deep_copy(orig_key)] = M.deep_copy(orig_value)
    end
    setmetatable(copy, M.deep_copy(getmetatable(orig)))
  else -- number, string, boolean, etc
    copy = orig
  end
  return copy
end

return M
