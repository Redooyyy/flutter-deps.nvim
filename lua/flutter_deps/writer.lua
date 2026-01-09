local M = {}

local function pubspec_path()
  return vim.fn.getcwd() .. '/pubspec.yaml'
end

function M.add_to_pubspec(name, version)
  local path = pubspec_path()
  local lines = vim.fn.readfile(path)

  local dep_line = '  ' .. name .. ': ^' .. version
  local inserted = false

  for i, line in ipairs(lines) do
    if line:match('^dependencies:') then
      table.insert(lines, i + 1, dep_line)
      inserted = true
      break
    end
  end

  if not inserted then
    table.insert(lines, '')
    table.insert(lines, 'dependencies:')
    table.insert(lines, dep_line)
  end

  vim.fn.writefile(lines, path)

  vim.fn.jobstart({ 'flutter', 'pub', 'get' }, { detach = true })
end

return M
