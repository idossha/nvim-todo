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
  
  -- Add leader keybind for stats
  vim.keymap.set("n", "<leader>ts", function()
    require("todo").stats()
  end, { desc = "Show todo statistics" })
  
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
