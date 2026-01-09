local M = {}

local function get_pubspec_path()
  local cwd = vim.fn.getcwd()
  return cwd .. '/pubspec.yaml'
end

local function read_file(path)
  local f = io.open(path, 'r')
  if not f then
    return ''
  end
  local content = f:read('*all')
  f:close()
  return content
end

local function write_file(path, content)
  local f = io.open(path, 'w')
  if not f then
    return false
  end
  f:write(content)
  f:close()
  return true
end

function M.add_to_pubspec(package_name, version)
  local path = get_pubspec_path()
  local content = read_file(path)

  -- Find 'dependencies:' section
  local dep_start = content:find('dependencies:')
  if not dep_start then
    -- If not found, append at end
    content = content .. '\ndependencies:\n'
    dep_start = #content
  end

  -- Add new dependency
  local dep_line = '  ' .. package_name .. ': ^' .. version .. '\n'
  content = content:sub(1, dep_start + #'dependencies:')
    .. '\n'
    .. dep_line
    .. content:sub(dep_start + #'dependencies:' + 1)

  write_file(path, content)

  -- Optional: run `flutter pub get`
  vim.fn.jobstart({ 'flutter', 'pub', 'get' }, { detach = true })
end

return M
