# 📝 todo.nvim

A lightweight and powerful Neovim plugin for managing todos directly from your editor.

## Features

- 📋 **Intuitive UI**: Beautiful floating window interface for todo management
- 🏷️ **Rich metadata**: Support for tags, projects, priorities, and due dates
- 📊 **Statistics**: Track your productivity with built-in statistics
- 🔍 **Search & Filter**: Easily find and filter todos by various criteria

## Requirements

- Neovim >= 0.7.0

## Installation

### Plugin Installation

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
  'idossha/todo.nvim',
  requires = {
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
    'nvim-lua/plenary.nvim',
  },
  config = function()
    require('todo').setup({
      storage = {
        path = vim.fn.stdpath("data") .. "/todo.json", -- Where to store the todo data
      },
      ui = {
        width = 60,        -- Width of the todo window
        height = 20,       -- Height of the todo window
        border = "rounded" -- Border style
      }
    })
  end
}
```

## Setup

By default, todos are stored in a JSON file at `~/.local/share/nvim/todo.json`. You can customize this location:

```lua
require('todo').setup({
  storage = {
    path = "/path/to/your/todo.json" -- Custom storage path
  }
})
```

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
