local M = {}

local api = vim.api
local todo = require("todo")

-- Register all plugin commands
function M.setup()
  -- Register user commands
  api.nvim_create_user_command("TodoOpen", function()
    todo.open()
  end, {
    desc = "Open the todo list window",
  })
  
  -- Add leader keybinds
  vim.keymap.set("n", "<leader>to", todo.open, { desc = "Open todo list" })
  vim.keymap.set("n", "<leader>ta", function() todo.add() end, { desc = "Add new todo" })
  vim.keymap.set("n", "<leader>ts", todo.stats, { desc = "Show todo statistics" })
  vim.keymap.set("n", "<leader>th", function() 
    if require("todo.ui").is_open() then
      require("todo.ui.actions").show_help()
    end
  end, { desc = "Show todo help" })
  
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
