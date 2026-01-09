local Job = require('plenary.job')
local M = {}

-- Cache to avoid repeated network calls
local cache = {}

-- Debounce helper
local function debounce(fn, delay)
  local timer_id
  return function(...)
    local args = { ... }
    if timer_id then
      vim.fn.timer_stop(timer_id)
    end
    timer_id = vim.fn.timer_start(delay, function()
      fn(unpack(args))
    end)
  end
end

-- Async search
function M.search(query, cb)
  if query == '' then
    return cb({})
  end
  if cache[query] then
    return cb(cache[query])
  end

  -- Use Plenary Job to fetch pub.dev API asynchronously
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
      vim.schedule_wrap(function()
        cb(results)
      end)()
    end,
  }):start()
end

-- Expose a debounced version for Telescope
M.debounced_search = debounce(M.search, 250)

return M
