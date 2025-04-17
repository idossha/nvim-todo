local M = {}

-- Function to parse date string to timestamp
local function parse_timestamp(date_str)
    local year, month, day, hour, min, sec = 
        date_str:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
    return os.time{
        year = tonumber(year),
        month = tonumber(month),
        day = tonumber(day),
        hour = tonumber(hour),
        min = tonumber(min),
        sec = tonumber(sec)
    }
end

-- Calculate completion statistics
function M.calculate_todo_stats(active_path, completed_path)
    -- Read file contents
    local function read_file(path)
        local file = io.open(path, "r")
        if file then
            local content = file:read("*all")
            file:close()
            return content
        end
        return nil
    end

    -- Count total and completed todos using improved regex
    local active_content = read_file(active_path) or ""
    local completed_content = read_file(completed_path) or ""
    
    -- Improved regex for counting todos with optional timestamp
    local function count_todos(content, completed)
        local count = 0
        for line in content:gmatch("[^\r\n]+") do
            local todo_pattern = completed and 
                "^%- %[x%].-%(Created: (%d+-%d+-%d+ %d+:%d+:%d+)%)%s*%(Completed: (%d+-%d+-%d+ %d+:%d+:%d+)%)" 
                or "^%- %[ %]"
            
            if line:match(todo_pattern) then
                count = count + 1
            end
        end
        return count
    end

    local total_todos = count_todos(active_content, false) + count_todos(completed_content, true)
    local active_todos = count_todos(active_content, false)
    local completed_todos = count_todos(completed_content, true)

    -- Calculate completion times for completed todos
    local completion_times = {}
    for create_time, complete_time in completed_content:gmatch("Created: (%d+-%d+-%d+ %d+:%d+:%d+).-Completed: (%d+-%d+-%d+ %d+:%d+:%d+)") do
        local create_timestamp = parse_timestamp(create_time)
        local complete_timestamp = parse_timestamp(complete_time)
        
        -- Calculate completion time in hours
        local completion_time = (complete_timestamp - create_timestamp) / 3600
        table.insert(completion_times, completion_time)
    end

    -- Calculate mean and standard deviation of completion times
    local function calculate_stats(times)
        if #times == 0 then return 0, 0 end
        
        -- Calculate mean
        local sum = 0
        for _, time in ipairs(times) do
            sum = sum + time
        end
        local mean = sum / #times
        
        -- Calculate standard deviation
        local variance_sum = 0
        for _, time in ipairs(times) do
            variance_sum = variance_sum + (time - mean)^2
        end
        local std_dev = math.sqrt(variance_sum / #times)
        
        return mean, std_dev
    end

    local mean_completion_time, std_dev_completion_time = calculate_stats(completion_times)

    -- Prepare stats string
    local stats_content = "# Todo Statistics\n\n"
    stats_content = stats_content .. string.format("## Completion Metrics\n\n")
    stats_content = stats_content .. string.format("- **Total Todos**: %d\n", total_todos)
    stats_content = stats_content .. string.format("- **Active Todos**: %d\n", active_todos)
    stats_content = stats_content .. string.format("- **Completed Todos**: %d\n", completed_todos)
    
    -- Calculate completion percentage
    local completion_percentage = total_todos > 0 and 
        (completed_todos / total_todos) * 100 or 0
    stats_content = stats_content .. string.format("- **Completion Rate**: %.2f%%\n\n", completion_percentage)
    
    stats_content = stats_content .. "## Completion Time Analysis\n\n"
    stats_content = stats_content .. string.format("- **Mean Completion Time**: %.2f hours\n", mean_completion_time)
    stats_content = stats_content .. string.format("- **Std Deviation of Completion Time**: %.2f hours\n", std_dev_completion_time)

    return stats_content
end

-- Write statistics to file
function M.update_statistics_file(active_path, completed_path, stats_path)
    local stats_content = M.calculate_todo_stats(active_path, completed_path)
    
    local file = io.open(stats_path, "w")
    if file then
        file:write(stats_content)
        file:close()
        return true
    end
    return false
end

return M
