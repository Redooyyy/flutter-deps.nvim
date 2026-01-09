local Job = require('plenary.job')
local M = {}

local cache = {}
local running_job = nil

function M.search(query, cb)
  if not cb then
    return
  end

  if query == '' then
    cb({})
    return
  end

  if cache[query] then
    cb(cache[query])
    return
  end

  -- Cancel previous job if still running
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

      if ok and data.packages then
        for _, pkg in ipairs(data.packages) do
          table.insert(results, {
            name = pkg.package,
            latest_version = pkg.version or 'latest',
          })
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
