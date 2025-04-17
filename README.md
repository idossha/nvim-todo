# 📝 Nvim Todo

A powerful and simple todo management plugin for Neovim that helps you organize, track, and visualize your tasks effortlessly.

## ✨ Features

- 🚀 Add todos from anywhere in Neovim
- ✅ Mark todos as completed with a single command
- 🗂️ Automatically archive completed todos
- 🕰️ Timestamp completed tasks
- 🔧 Fully configurable
- 📂 Markdown-based todo tracking
- 🔍 Optional Telescope integration

## 🚧 Requirements

- Neovim 0.7+
- Lua 5.1+
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
            todo_dir = vim.fn.expand("~/my-todos"),
            -- Optional: force disable telescope
            use_telescope = true
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

### Keybindings

- `<leader>ta` - Add a new todo
- `<leader>tc` - Complete current todo
- `<leader>tl` - List todos (uses Telescope if available)
- `<leader>td` - List completed todos

### Example Workflow

1. Add a todo: 
   ```
   :TodoAdd Implement new Neovim feature
   ```

2. When complete, place cursor on the todo and run:
   ```
   :TodoComplete
   ```

## 🛠️ Configuration

Default configuration:
```lua
{
    todo_dir = "~/todo",
    active_todo_file = "todos.md",
    completed_todo_file = "completed_todos.md",
    use_telescope = true  -- Automatically use Telescope if available
}
```

You can customize these settings in the `setup()` function.

## 📋 Todo Format

- Active todos: `- [ ] Task description`
- Completed todos: `- [x] Task description (Completed: timestamp)`

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.

## 🌟 Support

If you find this plugin helpful, please consider starring the repository!
