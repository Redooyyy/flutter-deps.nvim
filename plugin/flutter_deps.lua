-- Prevent multiple loads
if vim.g.loaded_flutter_deps then
  return
end
vim.g.loaded_flutter_deps = true

-- Load plugin
require('flutter_deps').setup()

-- Default keymap
vim.keymap.set('n', '<leader>pd', function()
  require('flutter_deps').add_dependency()
end, { desc = 'Add pub.dev dependency' })
