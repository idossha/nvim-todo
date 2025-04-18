-- Prevent loading this plugin multiple times
if vim.g.loaded_todo_nvim == 1 then
  return
end
vim.g.loaded_todo_nvim = 1

-- Create highlight groups
vim.cmd([[
  highlight default TodoNormal guibg=NONE ctermbg=NONE
  highlight default TodoBorder guifg=#555555 ctermfg=darkgray
  
  highlight default TodoPriorityHigh guifg=#FF5555 ctermfg=red
  highlight default TodoPriorityMedium guifg=#FFAA55 ctermfg=yellow
  highlight default TodoPriorityLow guifg=#AAAAAA ctermfg=gray
  
  highlight default TodoDueDate guifg=#55AAFF ctermfg=blue
  highlight default TodoTag guifg=#55FF55 ctermfg=green
  highlight default TodoProject guifg=#FF55FF ctermfg=magenta
  
  highlight default TodoCompleted guifg=#777777 ctermfg=gray gui=strikethrough cterm=strikethrough
]])

-- Define auto commands, if needed
-- (None defined here as the plugin primarily uses commands)
