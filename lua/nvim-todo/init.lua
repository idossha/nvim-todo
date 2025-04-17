-- Main plugin initialization
local core = require('nvim-todo.core')

return {
    setup = core.setup,
    add_todo = core.add_todo,
    complete_todo = core.complete_todo,
    open_todos = core.open_todos,
    open_completed_todos = core.open_completed_todos,
    open_statistics = core.open_statistics,
    find_todo_files = core.find_todo_files,
    live_grep_todos = core.live_grep_todos,
    debug_config = core.debug_config
}
