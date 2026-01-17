local M = {}
local writer = require('flutter_deps.writer')
local finder = require('flutter_deps.finder')
local Job = require('plenary.job')

-- Cache latest versions
local version_cache = {}

local function fetch_latest_version(pkg, cb)
  if version_cache[pkg] then
    cb(version_cache[pkg])
    return
  end

  Job:new({
    command = 'curl',
    args = { '-s', 'https://pub.dev/api/packages/' .. pkg },
    on_exit = function(j)
      local body = table.concat(j:result(), '\n')
      local ok, data = pcall(vim.fn.json_decode, body)
      local latest = 'unknown'
      if ok and data and data.latest and data.latest.pubspec.version then
        latest = data.latest.pubspec.version
      end
      version_cache[pkg] = latest
      vim.schedule(function()
        cb(latest)
      end)
    end,
  }):start()
end

function M.add_dependency()
  vim.ui.input({ prompt = 'Search pub.dev package:' }, function(query)
    if not query or #query < 2 then
      return
    end

    -- show loading immediately
    vim.ui.select({ 'loading...' }, { prompt = 'Fetching packages...' }, function(_) end)

    finder.search(query, function(packages)
      if not packages or #packages == 0 then
        vim.ui.select({ 'No results' }, { prompt = 'Search pub.dev' }, function(_) end)
        return
      end

      local display = {}
      local pkg_map = {}

      for _, pkg in ipairs(packages) do
        local line = pkg .. ' — loading...'
        table.insert(display, line)
        pkg_map[line] = pkg

        -- async fetch latest version for each package
        fetch_latest_version(pkg, function(ver)
          local updated = pkg .. ' — ' .. ver
          -- rebuild menu with updated entries
          local new_display = {}
          for _, p in ipairs(packages) do
            local v = version_cache[p] or 'loading...'
            table.insert(new_display, p .. ' — ' .. v)
            pkg_map[p .. ' — ' .. v] = p
          end
          vim.ui.select(new_display, { prompt = 'Select package' }, function(choice)
            if choice then
              local name, ver = choice:match('^(.-) — (.+)$')
              if name and ver and ver ~= 'loading...' and ver ~= 'unknown' then
                writer.add_to_pubspec(name, ver)
                vim.notify('Added ' .. name .. ' ^' .. ver, vim.log.levels.INFO)
              else
                vim.notify('Version not ready yet for ' .. name, vim.log.levels.WARN)
              end
            end
          end)
        end)
      end
    end)
  end)
end

return M
