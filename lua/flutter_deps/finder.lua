local Job = require('plenary.job')
local M = {}

local cache = {}

-- debounce helper
local function debounce(fn, delay)
  local timer
  return function(...)
    local args = { ... }
    if timer then
      vim.fn.timer_stop(timer)
    end
    timer = vim.fn.timer_start(delay, function()
      fn(unpack(args))
    end)
  end
end

function M.search(query, cb)
  -- SAFETY: if cb is missing, do nothing
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

  Job:new({
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
  }):start()
end

M.debounced_search = debounce(M.search, 250)

return M
