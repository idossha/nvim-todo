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
    year = tonumber(os.date("%Y")),
    month = tonumber(os.date("%m")),
    day = tonumber(os.date("%d")),
    hour = 0,
    min = 0,
    sec = 0
  })
  
  return timestamp < today
end

-- Check if a todo has a specific tag
function M.has_tag(tags, tag)
  if not tags or not tag then
    return false
  end
  
  for _, t in ipairs(tags) do
    if t:lower() == tag:lower() then
      return true
    end
  end
  
  return false
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
