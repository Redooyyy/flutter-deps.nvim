local M = {}
local writer = require('flutter_deps.writer')

local config = {
  keymap = '<leader>pd',
}

function M.setup(user_config)
  if user_config then
    for k, v in pairs(user_config) do
      config[k] = v
    end
  end
end

-- Cache: name -> latest version string
local latest_version_cache = {}
-- Cache: name -> list of all version strings (newest first)
local versions_cache = {}

-- Fetches /api/packages/<name> and calls cb with (latest_version, all_versions)
local function fetch_package_async(name, cb)
  local Job = require('plenary.job')
  Job:new({
    command = 'curl',
    args = { '-s', 'https://pub.dev/api/packages/' .. name },
    on_exit = function(j)
      local body = table.concat(j:result(), '\n')
      local ok, data = pcall(vim.fn.json_decode, body)

      local latest = nil
      local versions = {}

      if ok and data then
        if data.latest and data.latest.version then
          latest = data.latest.version
          latest_version_cache[name] = latest
        end
        if data.versions then
          for i = #data.versions, 1, -1 do
            local v = data.versions[i].version
            if v then
              table.insert(versions, v)
            end
          end
          versions_cache[name] = versions
        end
      end

      vim.schedule(function()
        cb(latest, versions)
      end)
    end,
  }):start()
end

-- Prefetch search results to warm latest_version_cache
local function prefetch_search(prompt)
  local Job = require('plenary.job')
  Job:new({
    command = 'curl',
    args = { '-s', 'https://pub.dev/api/search?q=' .. prompt },
    on_exit = function(j)
      local body = table.concat(j:result(), '\n')
      local ok, data = pcall(vim.fn.json_decode, body)
      if ok and data and data.packages then
        for _, pkg in ipairs(data.packages) do
          if pkg.package and pkg.latest and pkg.latest.version then
            latest_version_cache[pkg.package] = pkg.latest.version
          end
        end
      end
    end,
  }):start()
end

function M.add_dependency()
  local ok = pcall(require, 'telescope')
  if not ok then
    vim.notify('flutter-deps.nvim requires telescope.nvim', vim.log.levels.ERROR)
    return
  end

  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')

  pickers
    .new({}, {
      prompt_title = 'Search pub.dev packages',
      finder = finders.new_async_job({
        command_generator = function(prompt)
          if not prompt or #prompt < 2 then
            return nil
          end
          prefetch_search(prompt)
          return {
            'sh',
            '-c',
            "curl -s 'https://pub.dev/api/search?q=" .. prompt .. "' | jq -r '.packages[].package'",
          }
        end,
        entry_maker = function(line)
          if not line or line == '' then
            return nil
          end
          return {
            value = line,
            display = line,
            ordinal = line,
            name = line,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        -- ENTER: use cache if ready, otherwise fetch and wait
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          if not entry then
            return
          end
          actions.close(prompt_bufnr)

          local cached = latest_version_cache[entry.name]
          if cached then
            writer.add_to_pubspec(entry.name, cached)
            vim.notify('Added ' .. entry.name .. ' ^' .. cached, vim.log.levels.INFO)
          else
            vim.notify('Fetching version for ' .. entry.name .. '...', vim.log.levels.INFO)
            fetch_package_async(entry.name, function(latest, _)
              if not latest then
                vim.notify('Could not fetch version for ' .. entry.name, vim.log.levels.WARN)
                return
              end
              writer.add_to_pubspec(entry.name, latest)
              vim.notify('Added ' .. entry.name .. ' ^' .. latest, vim.log.levels.INFO)
            end)
          end
        end)

        -- TAB: use cache if ready, otherwise fetch and wait
        map('i', '<Tab>', function()
          local entry = action_state.get_selected_entry()
          if not entry then
            return
          end
          actions.close(prompt_bufnr)

          local function open_version_picker(versions)
            if #versions == 0 then
              vim.notify('No versions found for ' .. entry.name, vim.log.levels.WARN)
              return
            end
            pickers
              .new({}, {
                prompt_title = 'Select version for ' .. entry.name,
                finder = finders.new_table({ results = versions }),
                sorter = conf.generic_sorter({}),
                attach_mappings = function(bufnr)
                  actions.select_default:replace(function()
                    local ver = action_state.get_selected_entry()
                    actions.close(bufnr)
                    writer.add_to_pubspec(entry.name, ver.value)
                    vim.notify('Added ' .. entry.name .. ' ^' .. ver.value, vim.log.levels.INFO)
                  end)
                  return true
                end,
              })
              :find()
          end

          local cached = versions_cache[entry.name]
          if cached then
            open_version_picker(cached)
          else
            vim.notify('Fetching versions for ' .. entry.name .. '...', vim.log.levels.INFO)
            fetch_package_async(entry.name, function(_, versions)
              open_version_picker(versions)
            end)
          end
        end)

        return true
      end,
    })
    :find()
end

M.config = config
return M
