-- Main plugin initialization
local core = require('nvim-todo.core')

return {
    setup = core.setup,
    add_todo = core.add_todo,
    complete_todo = core.complete_todo,
    open_todos = core.open_todos,
    open_completed_todos = core.open_completed_todos
}
