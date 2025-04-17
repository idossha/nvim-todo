# Nvim Todo

A powerful and flexible todo management plugin for Neovim.

## ✨ Features

- 📝 Add, complete, and manage todos
- 🔍 Telescope integration for file finding and live grep
- 📊 Automatic statistics tracking
- 🕰️ Timestamped todos and completion tracking

## 🚧 Requirements

- Neovim 0.7+
- (Optional) Telescope.nvim for enhanced file browsing

## 📦 Installation

### Lazy.nvim

```lua
{
    'idossha/nvim-todo',
    dependencies = {
        -- Optional: for enhanced file browsing
        'nvim-telescope/telescope.nvim'
    },
    config = function()
        require('nvim-todo').setup({
            -- Optional: customize todo directory
            todo_dir = vim.fn.expand("~/my-todos")
        })
    end
}
```

### Packer.nvim

```lua
use {
    'idossha/nvim-todo',
    requires = {
        -- Optional: for enhanced file browsing
        'nvim-telescope/telescope.nvim'
    },
    config = function()
        require('nvim-todo').setup()
    end
}
```

## 🎮 Usage

### Commands

- `:TodoAdd <task description>` - Add a new todo item
- `:TodoComplete` - Mark the current todo item as completed
- `:TodoList` - Open active todo list
- `:TodoCompletedList` - Open completed todo list
- `:TodoStats` - Open todo statistics
- `:TodoFindFiles` - Find files in todo directory
- `:TodoLiveGrep` - Live grep todos

### Keybindings

- `<leader>ta` - Add a new todo
- `<leader>tc` - Complete current todo
- `<leader>tl` - List todos
- `<leader>td` - List completed todos
- `<leader>ts` - Open todo statistics
- `<leader>tf` - Find todo files
- `<leader>tg` - Live grep todos

## 🛠️ Configuration

```lua
require('nvim-todo').setup({
    todo_dir = "/path/to/todo/directory",
    active_todo_file = "todos.md",
    completed_todo_file = "completed_todos.md",
    statistics_file = "todo_stats.md"
})
```

## 📋 Todo Format

- Active todos: `- [ ] Task description (Created: timestamp)`
- Completed todos: `- [x] Task description (Completed: timestamp)`

## 🤝 Contributing

Contributions are welcome! Please submit pull requests or open issues.

## 📄 License

MIT License
