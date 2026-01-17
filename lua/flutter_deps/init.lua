local M = {}
local Job = require('plenary.job')
local writer = require('flutter_deps.writer')

-- search pub.dev
local function search_packages(query, cb)
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
      vim.schedule(function()
        cb(results)
      end)
    end,
  }):start()
end

-- fetch latest version
local function fetch_latest(pkg, cb)
  Job:new({
    command = 'curl',
    args = { '-s', 'https://pub.dev/api/packages/' .. pkg },
    on_exit = function(j)
      local body = table.concat(j:result(), '\n')
      local ok, data = pcall(vim.fn.json_decode, body)
      local ver = 'unknown'
      if ok and data and data.latest and data.latest.pubspec.version then
        ver = data.latest.pubspec.version
      end
      vim.schedule(function()
        cb(ver)
      end)
    end,
  }):start()
end

function M.add_dependency()
  vim.ui.input({ prompt = 'Search pub.dev package:' }, function(query)
    if not query or #query < 2 then
      return
    end

    vim.notify("Searching pub.dev for '" .. query .. "' ...")

    search_packages(query, function(pkgs)
      if #pkgs == 0 then
        vim.notify('No results for ' .. query, vim.log.levels.WARN)
        return
      end

      local results, pending = {}, #pkgs
      for _, pkg in ipairs(pkgs) do
        fetch_latest(pkg, function(ver)
          table.insert(results, pkg .. ' — ' .. ver)
          pending = pending - 1
          if pending == 0 then
            vim.ui.select(results, { prompt = 'Select package' }, function(choice)
              if choice then
                local name, version = choice:match('^(.-) — (.+)$')
                if name and version and version ~= 'unknown' then
                  writer.add_to_pubspec(name, version)
                  vim.notify('Added ' .. name .. ' ^' .. version, vim.log.levels.INFO)
                else
                  vim.notify('Version not ready yet for ' .. name, vim.log.levels.WARN)
                end
              end
            end)
          end
        end)
      end
    end)
  end)
end

return M
