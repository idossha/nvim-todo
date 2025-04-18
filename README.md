# 📝 todo.nvim

A simple and efficient todo management plugin for Neovim.

## Features

- Create and manage todos with descriptions
- Add tags, priorities, and due dates
- Sort and filter todos
- View todo statistics
- Automatic description preview when hovering over todos
- Simple and intuitive interface

## Requirements

- Neovim >= 0.7.0

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "idohaber/todo.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    require("todo").setup()
  end,
}
```

## Usage

### Commands

- `:TodoOpen` - Open the todo list window
- `:TodoAdd` - Add a new todo
- `:TodoStats` - Show todo statistics

### Keybindings

#### Global Keybindings

- `<leader>to` - Open todo list
- `<leader>ta` - Add new todo
- `<leader>ts` - Show todo statistics

#### Todo Window Keybindings

- `a` - Add new todo
- `d` - Delete todo under cursor
- `c` - Complete todo under cursor
- `e` - Edit todo under cursor
- `t` - Edit tags
- `p` - Set priority
- `D` - Set due date
- `s` - Sort todos
- `f` - Filter todos
- `q` - Close todo window
- `h` - Show help

### Description Preview

When you hover over a todo item that has a description, the description will automatically appear as an indented line below the todo item. The description is highlighted in the Comment highlight group for better visibility.

## Configuration

```lua
require("todo").setup({
  -- Default configuration
  mappings = {
    open = "<leader>to",
    add = "<leader>ta",
    delete = "d",
    complete = "c",
    edit = "e",
    tags = "t",
    priority = "p",
    due_date = "D",
    sort = "s",
    filter = "f",
    close = "q",
  },
})
```

## Statistics

The statistics window shows:
- Total number of todos
- Number of completed todos with percentage
- Number of pending todos
- Number of high priority todos
- Number of overdue todos
- Number of todos completed today
- Statistics by project
- Statistics by tag

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT
