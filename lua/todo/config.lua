local M = {}

-- Default configuration values
M.defaults = {
    -- Database configuration
    db_path = vim.fn.expand("~/.local/share/nvim/todo.nvim/todo.db"),
    
    -- UI Settings
    ui = {
        width = 80,        -- Width of the floating window
        height = 25,       -- Height of the floating window
        border = "rounded", -- Border style: "none", "single", "double", "rounded"
        icons = true,      -- Use icons in the UI
        mappings = {       -- Custom key mappings
            open = "<leader>to",
            add = "<leader>ta",
            global_add = "<leader>ta"
        }
    }
}

return M
