if vim.g.loaded_flutter_deps then
  return
end
vim.g.loaded_flutter_deps = true

vim.api.nvim_create_user_command('FlutterDepsAdd', function()
  require('flutter_deps').add_dependency()
end, {})
