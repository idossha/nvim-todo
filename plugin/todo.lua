-- Check if the plugin is already loaded
if vim.g.loaded_todo_nvim == 1 then
  return
end
vim.g.loaded_todo_nvim = 1

-- Set up commands
-- (actual registration is done in the setup function)

-- Export the main module
return require('todo')
