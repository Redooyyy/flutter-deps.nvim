-- Prevent multiple loads
if vim.g.loaded_flutter_deps then
  return
end
vim.g.loaded_flutter_deps = true

local flutter_deps = require('flutter_deps')
flutter_deps.setup()

-- Keymap
vim.keymap.set('n', flutter_deps.config.keymap, function()
  flutter_deps.add_dependency()
end, { desc = 'Add pub.dev dependency' })
