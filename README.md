# Nvim Todo

A modern and interactive todo manager for Neovim with a beautiful UI and SQLite database storage.

## ✨ Features

- 🎨 Beautiful floating window UI
- 💾 SQLite database for persistent storage
- 📊 Real-time statistics and tracking
- 🏷️ Tags and project support
- 📅 Due dates and prioritization
- 🔄 Instant synchronization between UI and database
- ⌨️ Intuitive keyboard-driven interface

## 📷 Screenshots

![Nvim Todo UI](/screenshots/todo-ui.png)
![Todo Stats](/screenshots/todo-stats.png)

## 🚧 Requirements

- Neovim 0.7+
- lsqlite3 Lua library for database functionality

## 📦 Installation

### Installing SQLite Dependencies

Before using the plugin, you need to install the lsqlite3 Lua library:

#### On Ubuntu/Debian:
```bash
sudo apt-get install -y libsqlite3-dev luarocks
sudo luarocks install lsqlite3
```

#### On macOS:
```bash
brew install sqlite luarocks
luarocks install lsqlite3
```

### Lazy.nvim

```lua
{
    'idossha/nvim-todo',
    config = function()
        require('nvim-todo').setup({
            -- Database location
            db_path = vim.fn.expand("~/.local/share/nvim/nvim-todo/todo.db"),
            -- UI settings
            ui = {
                width = 80,  -- Width of the floating window
                height = 25,  -- Height of the floating window
                border = "rounded",  -- Border style
                icons = true,  -- Use icons in the UI
                mappings = {  -- Custom key mappings
                    open = "<leader>to",
                    add = "<leader>ta"
                }
            }
        })
    end
}
```

### Packer.nvim

```lua
use {
    'idossha/nvim-todo',
    config = function()
        require('nvim-todo').setup({
            -- Optional: customize settings
            db_path = vim.fn.expand("~/.local/share/nvim/nvim-todo/todo.db"),
            ui = {
                width = 80,
                height = 25,
                border = "rounded"
            }
        })
    end
}
```

## 🎮 Usage

### Opening the UI

- Press `<leader>to` or run `:TodoOpen` to open the interactive UI

### Adding Todos

- Press `<leader>ta` or run `:TodoAdd` to add a new todo
- From the UI: Press `a` to add a new todo
- Syntax: `:TodoAdd Do something #tag @project due:2023-04-01`
- Priority: Use `!` or `!!` prefix, e.g. `:TodoAdd ! Important task`

### Working with Todos

Within the Todo UI:
- `j/k` - Navigate up/down
- `c` - Complete selected todo
- `d` - Delete selected todo
- `e` - Edit selected todo
- `1` - Switch to active todos
- `2` - Switch to completed todos
- `3` - Switch to statistics view
- `t` - Filter by tag
- `p` - Filter by project
- `s` - Search todos
- `r` - Refresh data
- `?` - Toggle help
- `q` - Close window

### Commands

- `:TodoOpen` - Open the Todo manager UI
- `:TodoAdd [content]` - Add a new todo
- `:TodoComplete [id]` - Complete a todo (opens UI if no ID provided)
- `:TodoOverdue` - Show overdue todos
- `:TodoToday` - Show todos due today
- `:TodoStats` - Show todo statistics
- `:TodoDebug` - Show debug information

## 🛠️ Configuration

```lua
require('nvim-todo').setup({
    -- Database settings
    db_path = "~/.local/share/nvim/nvim-todo/todo.db",
    
    -- UI settings
    ui = {
        width = 80,             -- Width of the floating window
        height = 25,            -- Height of the floating window
        border = "rounded",     -- Border style: "none", "single", "double", "rounded"
        icons = true,           -- Use icons in the UI
        -- Custom key mappings
        mappings = {
            open = "<leader>to",
            add = "<leader>ta"
        }
    }
})
```

## 📋 Todo Format

You can format your todos with various metadata:

- **Tags**: `#tag1 #tag2` - Add tags for organization
- **Projects**: `@project` - Assign to a project
- **Priority**: 
  - `! ` (one exclamation) - Medium priority
  - `!! ` (two exclamations) - High priority 
- **Due dates**: `due:YYYY-MM-DD` - Set a due date

Examples:
- `Buy milk #shopping due:2023-04-01`
- `!! Finish project report @work #urgent due:2023-03-15`
- `! Read chapter 5 #book @learning`

## 📊 Statistics

The plugin automatically tracks:
- Total number of todos
- Active and completed counts
- Completion rate
- Tasks completed today and this week
- Average completion time
- Tags and project statistics

## 🤝 Contributing

Contributions are welcome! Please submit pull requests or open issues.

## 📄 License

MIT License
