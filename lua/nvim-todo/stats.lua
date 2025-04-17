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

    -- Count total and completed todos
    local active_content = read_file(active_path)
    local completed_content = read_file(completed_path)
    
    if not active_content or not completed_content then
        return "Unable to read todo files."
    end

    -- Count active and completed todos
    local total_todos = 0
    for _ in active_content:gmatch("^%- %[ %]") do
        total_todos = total_todos + 1
    end
    
    local completed_todos = 0
    for _ in completed_content:gmatch("^%- %[x%]") do
        completed_todos = completed_todos + 1
    end

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
    stats_content = stats_content .. string.format("- **Total Todos**: %d\n", total_todos + completed_todos)
    stats_content = stats_content .. string.format("- **Active Todos**: %d\n", total_todos)
    stats_content = stats_content .. string.format("- **Completed Todos**: %d\n", completed_todos)
    
    -- Calculate completion percentage
    local completion_percentage = (completed_todos / (total_todos + completed_todos)) * 100
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
