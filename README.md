# 📝 todo.nvim

A lightweight and powerful Neovim plugin for managing todos directly from your editor.

## Features

- 🗃️ **Database-backed**: Store todos in an SQLite database for efficiency
- 📋 **Intuitive UI**: Beautiful floating window interface for todo management
- 🏷️ **Rich metadata**: Support for tags, projects, priorities, and due dates
- 📊 **Statistics**: Track your productivity with built-in statistics
- 🔍 **Search & Filter**: Easily find and filter todos by various criteria

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    "idossha/todo.nvim",
    config = function()
        require("todo").setup({
            -- Optional configuration (see Configuration section)
        })
    end,
    dependencies = {
        -- Required dependencies
        "kkharji/sqlite.lua", -- For SQLite database functionality
    }
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
    "idossha/todo.nvim",
    requires = {"kkharji/sqlite.lua"},
    config = function()
        require("todo").setup({
            -- Optional configuration (see Configuration section)
        })
    end
}
```

## Configuration

Here's a sample configuration with the default values:

```lua
require('todo').setup({
    -- Database configuration
    db_path = vim.fn.expand("~/.local/share/nvim/todo.nvim/todo.db"),
    -- UI Settings
    ui = {
        width = 80,  -- Width of the floating window
        height = 25,  -- Height of the floating window
        border = "rounded",  -- Border style: "none", "single", "double", "rounded"
        icons = true,  -- Use icons in the UI
        mappings = {  -- Custom key mappings
            open = "<leader>to",
            add = "<leader>ta",
            global_add = "<leader>ta"
        }
    }
})
```

## Usage

### Commands

| Command | Description |
|---------|-------------|
| `:TodoOpen` | Open the todo manager UI |
| `:TodoAdd [text]` | Add a new todo |
| `:TodoComplete [id]` | Complete a todo |
| `:TodoOverdue` | Show overdue todos |
| `:TodoToday` | Show todos due today |
| `:TodoStats` | Show todo statistics |

### Default Keybindings

| Keybinding | Action |
|------------|--------|
| `<leader>ta` | Add a new todo |
| `<leader>to` | Open todo manager |

### Todo UI Keybindings

| Key | Action |
|-----|--------|
| `j/k` | Navigate up/down |
| `1` | Switch to active todos tab |
| `2` | Switch to completed todos tab |
| `3` | Switch to statistics tab |
| `a` | Add new todo |
| `c` | Complete selected todo |
| `d` | Delete selected todo |
| `e` | Edit selected todo |
| `t` | Filter by tag |
| `p` | Filter by project |
| `s` | Search todos |
| `r` | Refresh data |
| `q` | Close window |
| `?` | Toggle help |

## Todo Syntax

Todos support metadata through special syntax:

- **Priority**: Start with `!` or `!!` for medium or high priority
- **Tags**: Use `#tag` to add tags
- **Project**: Use `@project` to assign to a project 
- **Due date**: Use `due:YYYY-MM-DD` to set a due date

Example: `!! Finish documentation #docs @blog due:2023-08-15`

## Troubleshooting

### Missing SQLite
The plugin requires the Lua SQLite module. If you see an error about SQLite, make sure you have installed `sqlite.lua` and that it's working correctly.

### Database errors
If you encounter database-related errors, try deleting the database file (`~/.local/share/nvim/todo.nvim/todo.db` by default) and restarting Neovim.

## License

MIT
