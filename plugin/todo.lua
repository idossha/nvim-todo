-- Prevent reloading
if vim.g.loaded_todo then
    return
end
vim.g.loaded_todo = true

-- Import the main module and setup with defaults
require('todo').setup() 