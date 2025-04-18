local M = {}
local todo = require("todo")

-- Register all plugin commands
function M.register()
    -- Define commands
    vim.cmd([[
        command! TodoOpen lua require('todo').open()
        command! -nargs=? TodoAdd lua require('todo').add(<q-args>)
        command! -nargs=1 TodoComplete lua require('todo').complete(<args>)
        command! TodoOverdue lua require('todo').overdue()
        command! TodoToday lua require('todo').today()
        command! TodoStats lua require('todo').stats()
    ]])
    
    -- Register keymappings
    local config = todo.config
    if config.ui.mappings then
        local mappings = config.ui.mappings
        
        if mappings.open then
            vim.api.nvim_set_keymap('n', mappings.open, ':TodoOpen<CR>', { noremap = true, silent = true })
        end
        
        if mappings.add then
            vim.api.nvim_set_keymap('n', mappings.add, ':TodoAdd<CR>', { noremap = true, silent = true })
        end
        
        if mappings.global_add then
            vim.api.nvim_set_keymap('n', mappings.global_add, ':TodoAdd<CR>', { noremap = true, silent = true })
        end
    end
end

return M
