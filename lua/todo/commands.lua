local M = {}

local api = vim.api
local todo = require("todo")
local config = require("todo.config")

-- Register all plugin commands
function M.setup()
  -- Register user commands
  api.nvim_create_user_command("TodoOpen", function()
    todo.open()
  end, {
    desc = "Open the todo list window",
  })
  
  -- Add keybindings for todo commands
  vim.keymap.set("n", config.default_config.mappings.open, function()
    require("todo.ui").open()
  end, { desc = "Open todo list" })

  vim.keymap.set("n", config.default_config.mappings.add, function()
    require("todo.ui").open()
    require("todo.ui.actions").add_todo()
  end, { desc = "Add new todo" })

  vim.keymap.set("n", config.default_config.mappings.delete, function()
    require("todo.ui").open()
    require("todo.ui.actions").delete_todo_under_cursor()
  end, { desc = "Delete todo under cursor" })

  vim.keymap.set("n", config.default_config.mappings.complete, function()
    require("todo.ui").open()
    require("todo.ui.actions").complete_todo_under_cursor()
  end, { desc = "Complete todo under cursor" })

  vim.keymap.set("n", config.default_config.mappings.edit, function()
    require("todo.ui").open()
    require("todo.ui.actions").edit_todo_under_cursor()
  end, { desc = "Edit todo under cursor" })

  vim.keymap.set("n", config.default_config.mappings.tags, function()
    require("todo.ui").open()
    require("todo.ui.actions").edit_tags()
  end, { desc = "Edit todo tags" })

  vim.keymap.set("n", config.default_config.mappings.priority, function()
    require("todo.ui").open()
    require("todo.ui.actions").set_priority()
  end, { desc = "Set todo priority" })

  vim.keymap.set("n", config.default_config.mappings.due_date, function()
    require("todo.ui").open()
    require("todo.ui.actions").set_due_date()
  end, { desc = "Set todo due date" })

  vim.keymap.set("n", config.default_config.mappings.sort, function()
    require("todo.ui").open()
    require("todo.ui.actions").show_sort_menu()
  end, { desc = "Sort todos" })

  vim.keymap.set("n", config.default_config.mappings.filter, function()
    require("todo.ui").open()
    require("todo.ui.actions").show_filter_menu()
  end, { desc = "Filter todos" })

  vim.keymap.set("n", config.default_config.mappings.close, function()
    require("todo.ui").close()
  end, { desc = "Close todo list" })
  
  api.nvim_create_user_command("TodoAdd", function(opts)
    local args = opts.args
    if args and args ~= "" then
      todo.add({ title = args })
    else
      todo.add()
    end
  end, {
    desc = "Add a new todo",
    nargs = "?",
  })
  
  api.nvim_create_user_command("TodoComplete", function(opts)
    local id = tonumber(opts.args)
    if not id then
      vim.notify("TodoComplete requires a todo ID", vim.log.levels.ERROR)
      return
    end
    
    todo.complete(id)
  end, {
    desc = "Mark a todo as completed",
    nargs = 1,
  })
  
  api.nvim_create_user_command("TodoDelete", function(opts)
    local id = tonumber(opts.args)
    if not id then
      vim.notify("TodoDelete requires a todo ID", vim.log.levels.ERROR)
      return
    end
    
    todo.delete(id)
  end, {
    desc = "Delete a todo",
    nargs = 1,
  })
  
  api.nvim_create_user_command("TodoStats", function()
    todo.stats()
  end, {
    desc = "View todo statistics",
  })
end

return M
