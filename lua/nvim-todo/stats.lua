local M = {}

local utils = require('nvim-todo.utils')
local config = require('nvim-todo.config')
local files = require('nvim-todo.files')

-- Parse todo files to get statistics
local function calculate_file_stats()
    local active_path = config.get_active_todo_path()
    local completed_path = config.get_completed_todo_path()
    
    -- Parse todos from files
    local active_todos = files.parse_todos(active_path)
    local completed_todos = files.parse_todos(completed_path)
    
    -- Count todos
    local active_count = #active_todos
    local completed_count = #completed_todos
    local total_count = active_count + completed_count
    
    -- Calculate completion rate
    local completion_rate = 0
    if total_count > 0 then
        completion_rate = (completed_count / total_count) * 100
    end
    
    -- Calculate completion time statistics
    local completion_times = {}
    for _, todo in ipairs(completed_todos) do
        if todo.created_at and todo.completed_at then
            -- Parse timestamps
            local created_time = os.time({
                year = todo.created_at:match("(%d+)%-(%d+)%-(%d+) (%d+):(%d+):(%d+)"),
                month = todo.created_at:match("%d+%-(%d+)%-(%d+) (%d+):(%d+):(%d+)"),
                day = todo.created_at:match("%d+%-%d+%-(%d+) (%d+):(%d+):(%d+)"),
                hour = todo.created_at:match("%d+%-%d+%-%d+ (%d+):(%d+):(%d+)"),
                min = todo.created_at:match("%d+%-%d+%-%d+ %d+:(%d+):(%d+)"),
                sec = todo.created_at:match("%d+%-%d+%-%d+ %d+:%d+:(%d+)")
            })
            
            local completed_time = os.time({
                year = todo.completed_at:match("(%d+)%-(%d+)%-(%d+) (%d+):(%d+):(%d+)"),
                month = todo.completed_at:match("%d+%-(%d+)%-(%d+) (%d+):(%d+):(%d+)"),
                day = todo.completed_at:match("%d+%-%d+%-(%d+) (%d+):(%d+):(%d+)"),
                hour = todo.completed_at:match("%d+%-%d+%-%d+ (%d+):(%d+):(%d+)"),
                min = todo.completed_at:match("%d+%-%d+%-%d+ %d+:(%d+):(%d+)"),
                sec = todo.completed_at:match("%d+%-%d+%-%d+ %d+:%d+:(%d+)")
            })
            
            if created_time and completed_time then
                -- Calculate difference in hours
                local diff_hours = (completed_time - created_time) / 3600
                table.insert(completion_times, diff_hours)
            end
        end
    end
    
    -- Calculate average completion time
    local avg_completion_time = 0
    if #completion_times > 0 then
        local sum = 0
        for _, time in ipairs(completion_times) do
            sum = sum + time
        end
        avg_completion_time = sum / #completion_times
    end
    
    -- Calculate standard deviation
    local std_dev_completion_time = 0
    if #completion_times > 1 then
        local variance = 0
        for _, time in ipairs(completion_times) do
            local diff = time - avg_completion_time
            variance = variance + (diff * diff)
        end
        variance = variance / (#completion_times - 1)
        std_dev_completion_time = math.sqrt(variance)
    end
    
    return {
        total_count = total_count,
        active_count = active_count,
        completed_count = completed_count,
        completion_rate = completion_rate,
        avg_completion_time = avg_completion_time,
        std_dev_completion_time = std_dev_completion_time
    }
end

-- Format statistics data into a markdown string
function M.format_statistics_content(stats)
    local content = "# Todo Statistics\n\n"
    
    -- Completion metrics
    content = content .. "## Completion Metrics\n\n"
    content = content .. string.format("- **Total Todos**: %d\n", stats.total_count)
    content = content .. string.format("- **Active Todos**: %d\n", stats.active_count)
    content = content .. string.format("- **Completed Todos**: %d\n", stats.completed_count)
    content = content .. string.format("- **Completion Rate**: %.2f%%\n\n", stats.completion_rate)
    
    -- Time analysis
    content = content .. "## Completion Time Analysis\n\n"
    content = content .. string.format("- **Mean Completion Time**: %.2f hours\n", stats.avg_completion_time)
    content = content .. string.format("- **Std Deviation of Completion Time**: %.2f hours\n", stats.std_dev_completion_time)
    
    return content
end

-- Update the statistics file based on current todos
function M.update_statistics_file()
    local stats_path = config.get_statistics_path()
    
    -- Calculate statistics from files
    local stats = calculate_file_stats()
    
    -- Generate and write statistics content
    local content = M.format_statistics_content(stats)
    utils.write_to_file(stats_path, content, "w")
    
    return true
end

return M
