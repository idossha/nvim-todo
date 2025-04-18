# 📝 todo.nvim

A lightweight and powerful Neovim plugin for managing todos directly from your editor.

## Features

- 📋 **Intuitive UI**: Beautiful floating window interface for todo management
- 🏷️ **Rich metadata**: Support for tags, projects, priorities, and due dates
- 📊 **Statistics**: Track your productivity with built-in statistics
- 🔍 **Search & Filter**: Easily find and filter todos by various criteria

## Requirements

- Neovim >= 0.7.0
- [tpope/vim-dadbod](https://github.com/tpope/vim-dadbod) for database connection
- PostgreSQL database

## Installation

### Plugin Installation

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
  'idossha/todo.nvim',
  requires = {
    'tpope/vim-dadbod',
    'nvim-lua/plenary.nvim', -- For utilities
  },
  config = function()
    require('todo').setup({
      -- Your configuration here
    })
  end
}
```

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'idossha/todo.nvim',
  dependencies = {
    'tpope/vim-dadbod',
    'nvim-lua/plenary.nvim',
  },
  config = function()
    require('todo').setup({
      -- Your configuration here
    })
  end
}
```

### PostgreSQL Installation and Setup

#### macOS

1. Install PostgreSQL using Homebrew:

```bash
# Install PostgreSQL
brew install postgresql@14

# Start PostgreSQL service
brew services start postgresql@14

# Check your username
whoami
# This will output your macOS username, which you'll use in the connection string

# Create the database for your todos
createdb neovim_todos

# If you get socket errors, you might need to add PostgreSQL to your PATH
echo 'export PATH="/opt/homebrew/opt/postgresql@14/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
# Then try creating the database again
createdb neovim_todos
```

#### Linux (Ubuntu/Debian)

```bash
# Install PostgreSQL
sudo apt-get update
sudo apt-get install postgresql postgresql-contrib

# Start PostgreSQL service
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Switch to postgres user to create a user and database
sudo -u postgres psql

# In the PostgreSQL prompt, create a user and database
postgres=# CREATE USER your_username WITH PASSWORD 'your_password';
postgres=# CREATE DATABASE neovim_todos OWNER your_username;
postgres=# \q

# Test connection
psql -U your_username -d neovim_todos
```

#### Windows

1. Download and install PostgreSQL from the [official website](https://www.postgresql.org/download/windows/)
2. During installation, set a password for the postgres user
3. Use pgAdmin or the command line to create a new database named `neovim_todos`

## Setup

1. Configure the plugin with your database connection in your Neovim config:

```lua
require('todo').setup({
  db = {
    -- For macOS with Homebrew (no password required for local connections)
    url = "postgresql://yourusername@localhost/neovim_todos"
    
    -- For Linux/Windows or if you've set a password
    -- url = "postgresql://username:password@localhost/neovim_todos"
  },
  ui = {
    width = 60,        -- Width of the todo window
    height = 20,       -- Height of the todo window
    border = "rounded" -- Border style
  },
  mappings = {
    -- Key mappings (see "Default Mappings" section)
  }
})
```

2. Once configured, the plugin will automatically initialize the database schema when you first run `:TodoOpen`

3. If you need to check if the database is properly connected, run `:TodoOpen` and check for any error notifications.

## Usage

Default commands:

- `:TodoOpen` - Open the todo list window
- `:TodoAdd` - Add a new todo
- `:TodoComplete <id>` - Mark a todo as completed
- `:TodoDelete <id>` - Delete a todo
- `:TodoStats` - View productivity statistics

## Default Mappings

When the todo window is open:

- `a` - Add a new todo
- `d` - Delete the todo under cursor
- `c` - Complete the todo under cursor
- `e` - Edit the todo under cursor
- `t` - Add/edit tags
- `p` - Set priority (H/M/L)
- `D` - Set due date
- `s` - Sort todos
- `f` - Filter todos
- `q` - Close window
- `?` - Show help

## License

MIT
