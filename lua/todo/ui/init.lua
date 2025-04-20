local M = {}

local api = vim.api
local storage = require("todo.storage")
local config = require("todo").config

-- Import sub-modules
local window = require("todo.ui.window")
local actions = require("todo.ui.actions")
local render = require("todo.ui.render")

-- UI state
M.state = {
  buffer = nil,
  window = nil,
  showing_help = false,
  help_start_line = nil,
  help_end_line = nil,
  showing_description = false,
  description_line = nil,
  current_filter = nil,
  current_sort = nil,
  sort_ascending = true,
  last_sort = nil,
  todos = {},
  filter = {
    completed = false,
    priority = nil,
    project = nil,
    tag = nil,
    due_date = nil,
  },
  sort = {
    field = "priority",
    ascending = true,
  },
}

function M.get_state()
  return M.state
end

-- Check if the UI is open
function M.is_open()
  return M.state.buffer ~= nil and api.nvim_buf_is_valid(M.state.buffer) and
         M.state.window ~= nil and api.nvim_win_is_valid(M.state.window)
end

-- Open the todo window
function M.open()
  window.create(M.state)
  M.refresh()
end

-- Close the todo window
function M.close()
  if M.is_open() then
    api.nvim_win_close(M.state.window, true)
    M.state.window = nil
    M.state.buffer = nil
  end
end

-- Refresh the todo list
function M.refresh()
  local todos = storage.get_todos(M.state.filter)
  M.state.todos = todos or {}
  
  -- Apply current sort
  render.sort_todos(M.state)
  
  -- Render the todos
  render.render_todos(M.state)
end

-- Add the action functions to M
M.add_todo = actions.add_todo
M.delete_todo_under_cursor = actions.delete_todo_under_cursor
M.complete_todo_under_cursor = actions.complete_todo_under_cursor
M.edit_todo_under_cursor = actions.edit_todo_under_cursor
M.edit_tags = actions.edit_tags
M.set_priority = actions.set_priority
M.set_due_date = actions.set_due_date
M.show_sort_menu = actions.show_sort_menu
M.show_filter_menu = actions.show_filter_menu
M.show_help = actions.show_help

return M
