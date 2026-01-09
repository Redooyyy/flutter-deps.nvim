local M = {}

function M.search(query)
  local results = {}
  local handle = io.popen('curl -s https://pub.dev/api/search?q=' .. query)
  if not handle then
    return results
  end
  local body = handle:read('*a')
  handle:close()

  local data = vim.fn.json_decode(body)
  if not data.packages then
    return results
  end

  for _, pkg in ipairs(data.packages) do
    table.insert(results, {
      name = pkg.package,
      latest_version = pkg.version or 'latest',
    })
  end
  return results
end

return M
