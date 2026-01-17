local Job = require('plenary.job')
local M = {}

local cache = {}
local running_job = nil

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

  if running_job then
    running_job:shutdown()
    running_job = nil
  end

  running_job = Job:new({
    command = 'curl',
    args = { '-s', 'https://pub.dev/api/search?q=' .. query },
    on_exit = function(j)
      local body = table.concat(j:result(), '\n')
      local ok, data = pcall(vim.fn.json_decode, body)
      local results = {}

      if ok and data and data.packages then
        for _, pkg in ipairs(data.packages) do
          table.insert(results, { name = pkg.package })
        end
      end

      cache[query] = results
      vim.schedule(function()
        cb(results)
      end)
    end,
  })

  running_job:start()
end

return M
