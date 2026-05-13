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

-- Cache: name -> { latest: string, versions: []string }
local pkg_cache = {}

local function fetch_package_async(name, cb)
  if pkg_cache[name] then
    cb(pkg_cache[name])
    return
  end

  local Job = require('plenary.job')
  Job:new({
    command = 'curl',
    args = { '-s', 'https://pub.dev/api/packages/' .. name },
    on_exit = function(j)
      local body = table.concat(j:result(), '\n')
      local ok, data = pcall(vim.fn.json_decode, body)

      local result = { latest = nil, versions = {} }

      if ok and data then
        -- Detail API: latest version is at data.latest.version
        if data.latest and data.latest.version then
          result.latest = data.latest.version
        end
        -- All versions: each item has a top-level .version field
        if data.versions then
          for i = #data.versions, 1, -1 do
            local v = data.versions[i].version
            if v then
              table.insert(result.versions, v)
            end
          end
        end
      end

      pkg_cache[name] = result
      vim.schedule(function()
        cb(result)
      end)
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
        -- ENTER → fetch detail API, add latest version
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          if not entry then
            return
          end
          actions.close(prompt_bufnr)

          vim.notify('Fetching ' .. entry.name .. '...', vim.log.levels.INFO)
          fetch_package_async(entry.name, function(pkg)
            if not pkg.latest then
              vim.notify('Could not fetch version for ' .. entry.name, vim.log.levels.WARN)
              return
            end
            writer.add_to_pubspec(entry.name, pkg.latest)
            vim.notify('Added ' .. entry.name .. ' ^' .. pkg.latest, vim.log.levels.INFO)
          end)
        end)

        -- TAB → fetch detail API, open version picker
        map('i', '<Tab>', function()
          local entry = action_state.get_selected_entry()
          if not entry then
            return
          end
          actions.close(prompt_bufnr)

          vim.notify('Fetching versions for ' .. entry.name .. '...', vim.log.levels.INFO)
          fetch_package_async(entry.name, function(pkg)
            if #pkg.versions == 0 then
              vim.notify('No versions found for ' .. entry.name, vim.log.levels.WARN)
              return
            end

            pickers
              .new({}, {
                prompt_title = 'Select version for ' .. entry.name,
                finder = finders.new_table({ results = pkg.versions }),
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
          end)
        end)

        return true
      end,
    })
    :find()
end

M.config = config
return M
