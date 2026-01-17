local Job = require('plenary.job')
local M = {}

-- Cache search results
local cache = {}

function M.search(query, cb)
  if not cb then
    return
  end
  if #query < 2 then
    cb({})
    return
  end

  if cache[query] then
    cb(cache[query])
    return
  end

  Job:new({
    command = 'curl',
    args = { '-s', 'https://pub.dev/api/search?q=' .. query },
    on_exit = function(j)
      local body = table.concat(j:result(), '\n')
      local ok, data = pcall(vim.fn.json_decode, body)
      local results = {}

      if ok and data and data.packages then
        for _, pkg in ipairs(data.packages) do
          table.insert(results, pkg.package)
        end
      end

      cache[query] = results
      vim.schedule(function()
        cb(results)
      end)
    end,
  }):start()
end

return M
