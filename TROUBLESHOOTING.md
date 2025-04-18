# Troubleshooting Guide for todo.nvim

This guide addresses common issues that you might encounter when using todo.nvim.

## Circular Dependencies Error

**Error:**
```
Failed to run `config` for todo.nvim
/Users/idossha/.config/nvim/lua/idossha/plugins/todo.lua:4: loop or previous error loading module 'todo'
```

**Solution:**

This error occurs due to circular module dependencies in the plugin. We've fixed this by:

1. Restructuring the `init.lua` file to load modules in the correct order
2. Using lazy-loading for the UI module in core.lua
3. Ensuring proper initialization in the setup function

If you're still experiencing this error:
- Make sure you're using the latest version of the plugin
- Try removing any custom configurations temporarily to see if they're causing issues
- Check if you have any other plugins that might be conflicting with todo.nvim

## SQLite Syntax Error

**Error:**
```
...er/.local/share/nvim/lazy/todo.nvim/lua/todo/db.lua:301: unexpected symbol near '}'
```

**Solution:**

This error was caused by syntax errors in the db.lua file. We've fixed this by:
- Correcting improper usage of curly braces `{}` that should have been parentheses `()`
- Ensuring all code blocks are properly closed

If you encounter similar errors:
1. Check if you've modified any of the plugin's source files
2. Ensure you're using the latest version of the plugin
3. Try reinstalling the plugin

## SQLite Library Missing

**Error:**
```
SQLite3 not found. Please install lsqlite3 for Lua.
```

**Solution:**

This plugin requires the sqlite.lua library:

1. Add the dependency to your plugin manager:

   ```lua
   -- For lazy.nvim
   dependencies = {
     "kkharji/sqlite.lua",
   }
   
   -- For packer
   requires = {"kkharji/sqlite.lua"}
   ```

2. Make sure you have the SQLite system dependencies installed:

   **macOS:**
   ```bash
   brew install sqlite
   ```

   **Ubuntu/Debian:**
   ```bash
   sudo apt-get install libsqlite3-dev
   ```

## Database Access Issues

If you're experiencing problems with the database:

1. Check file permissions:
   - The plugin tries to create a database at `~/.local/share/nvim/todo.nvim/todo.db`
   - Ensure your user has write permissions to this location

2. Reset the database:
   ```bash
   rm ~/.local/share/nvim/todo.nvim/todo.db
   ```

3. Specify a custom database location in your config:
   ```lua
   require('todo').setup({
       db_path = vim.fn.expand("~/custom/path/todo.db"),
   })
   ```

## Plugin Loading Issues

If the plugin fails to load correctly:

1. Check your plugin manager setup
2. Ensure you're calling `setup()` after loading the plugin:
   ```lua
   require('todo').setup({
       -- Your configuration here
   })
   ```
3. Try with minimal configuration first, then add your customizations

## Getting Help

If you've tried the solutions above and still experience issues:

1. Open an issue on the GitHub repository with:
   - A description of the problem
   - Steps to reproduce
   - Your Neovim version (`:version`)
   - Your plugin configuration
   - Any relevant error messages

2. Check the existing issues to see if someone has already reported and solved your problem. 