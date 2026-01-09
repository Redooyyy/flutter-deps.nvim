local M = {}

local https = require('ssl.https')
local json = vim.fn.json_decode

function M.search(query)
  local url = 'https://pub.dev/api/search?q=' .. query
  local body, code = https.request(url)
  local results = {}

  if code ~= 200 or not body then
    print('Error fetching pub.dev packages')
    return results
  end

  local data = json(body)

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
