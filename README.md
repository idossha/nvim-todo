# Nvim Todo

A powerful and flexible todo management plugin for Neovim with database support for data portability and a modular, maintainable codebase.

## ✨ Features

- 📝 Add, complete, and manage todos
- 🔍 Telescope integration for searching and browsing
- 📊 Automatic statistics tracking
- 🕰️ Timestamped todos and completion tracking
- 💾 SQLite database for data portability between machines
- 🔄 Seamless migration between file and database storage
- 🔖 Tag support for todo organization (#tag in todo text)
- 🏗️ Modular, maintainable architecture

## 🚧 Requirements

- Neovim 0.7+
- lsqlite3 Lua library (for database functionality)
- (Optional) Telescope.nvim for enhanced search and browsing

## 📦 Installation

### Installing SQLite Dependencies

Before using the database features, you need to install the lsqlite3 Lua library:

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
    dependencies = {
        -- Optional: for enhanced search and browsing
        'nvim-telescope/telescope.nvim'
    },
    config = function()
        require('nvim-todo').setup({
            -- Optional: customize todo directory
            todo_dir = vim.fn.expand("~/.local/share/nvim/nvim-todo/files"),
            -- Database settings
            use_database = true,
            db_path = vim.fn.expand("~/.local/share/nvim/nvim-todo/todo.db"),
            auto_migrate = true,
            view_mode = "database" -- "database" or "files"
        })
    end
}
```

### Packer.nvim

```lua
use {
    'idossha/nvim-todo',
    requires = {
        -- Optional: for enhanced search and browsing
        'nvim-telescope/telescope.nvim'
    },
    config = function()
        require('nvim-todo').setup({
            -- Optional: customize settings
            todo_dir = vim.fn.expand("~/.local/share/nvim/nvim-todo/files"),
            -- Database settings
            use_database = true,
            db_path = vim.fn.expand("~/.local/share/nvim/nvim-todo/todo.db"),
            auto_migrate = true,
            view_mode = "database" -- "database" or "files"
        })
    end
}
```

## 🎮 Usage

### Basic Commands

- `:TodoAdd <task description>` - Add a new todo item
- `:TodoComplete` - Mark a todo item as completed (with selection UI)
- `:TodoList` - Open active todo list
- `:TodoCompletedList` - Open completed todo list
- `:TodoStats` - Open todo statistics
- `:TodoFindFiles` - Find files in todo directory
- `:TodoLiveGrep` - Live grep todos
- `:TodoSearch` - Search todos with UI

### Database-specific Commands

- `:TodoMigrateToDb` - Migrate todos from files to database
- `:TodoExportToFiles` - Export todos from database to files
- `:TodoToggleViewMode` - Toggle between database and file view mode
- `:TodoDebug` - Show debug information about configuration

### Keybindings

- `<leader>ta` - Add a new todo
- `<leader>tc` - Complete a todo
- `<leader>to` - Open todos
- `<leader>th` - Open completed todos
- `<leader>ts` - Open todo statistics
- `<leader>tf` - Find todo files
- `<leader>tg` - Live grep todos
- `<leader>ts` - Search todos

## 🛠️ Configuration

```lua
require('nvim-todo').setup({
    -- File locations
    todo_dir = "~/.local/share/nvim/nvim-todo/files",
    active_todo_file = "todos.md",
    completed_todo_file = "completed_todos.md",
    statistics_file = "todo_stats.md",
    
    -- Telescope integration
    use_telescope = true,  -- If telescope is available
    
    -- Database settings
    use_database = true,  -- Enable database functionality
    db_path = "~/.local/share/nvim/nvim-todo/todo.db",  -- Path to SQLite database
    
    -- Migration settings
    auto_migrate = true,  -- Automatically migrate from files to DB on startup
    
    -- View mode
    view_mode = "database"  -- "database" or "files"
})
```

## 💾 Database Migration

When you enable the database functionality for the first time, the plugin can automatically migrate your existing todos from Markdown files to the SQLite database. This ensures a smooth transition to the new storage system.

You can also manually trigger migration:

```
:TodoMigrateToDb
```

To switch back to file view mode temporarily:

```
:TodoToggleViewMode
```

## 📋 Todo Format

Todos support tagging with hashtags: `Do something #important #work`

In the database, todos are stored with the following attributes:
- ID (unique identifier)
- Content (the text of the todo)
- Created timestamp
- Completed timestamp (if applicable)
- Status (active or completed)
- Tags (extracted from content)

When viewing in the editor, todos appear as:
- Active todos: `[ ] Task description (Created: timestamp)`
- Completed todos: `[x] Task description (Created: timestamp) (Completed: timestamp)`

## 🔄 Data Portability

One of the key benefits of the SQLite database is data portability. To move your todos to another machine:

1. Copy the database file (default location: `~/.local/share/nvim/nvim-todo/todo.db`)
2. Place it in the same location on the target machine
3. Ensure lsqlite3 is installed on the target machine

The database contains all your todos, tags, and statistics, making the transition seamless.

## 🏗️ Architecture

The plugin uses a modular architecture for better maintainability:

- `init.lua` - Main entry point, exports public API
- `core.lua` - Core functionality and coordination
- `config.lua` - Configuration management
- `utils.lua` - Utility functions
- `db.lua` - Database operations
- `files.lua` - File-based storage operations
- `ui.lua` - User interface components
- `stats.lua` - Statistics calculations
- `migration.lua` - Migration between storage systems

## 🤝 Contributing

Contributions are welcome! Please submit pull requests or open issues.

## 📄 License

MIT License
