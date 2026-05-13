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

-- Cache for full version list (only fetched on TAB)
local versions_cache = {}

local function fetch_versions_async(name, cb)
  if versions_cache[name] then
    cb(versions_cache[name])
    return
  end

  local Job = require('plenary.job')
  Job:new({
    command = 'curl',
    args = { '-s', 'https://pub.dev/api/packages/' .. name },
    on_exit = function(j)
      local body = table.concat(j:result(), '\n')
      local ok, data = pcall(vim.fn.json_decode, body)
      local versions = {}

      if ok and data and data.versions then
        for i = #data.versions, 1, -1 do
          local v = data.versions[i].version
          if v then
            table.insert(versions, v)
          end
        end
      end

      versions_cache[name] = versions
      vim.schedule(function()
        cb(versions)
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
        -- Fetch JSON directly and emit one compact object per line.
        -- This gives entry_maker the name AND latest.version in one shot,
        -- so Enter never needs a second API call.
        command_generator = function(prompt)
          if not prompt or #prompt < 2 then
            return nil
          end
          return {
            'sh',
            '-c',
            "curl -s 'https://pub.dev/api/search?q="
              .. prompt
              .. "' | jq -c '.packages[] | {name: .package, version: .latest.version}'",
          }
        end,
        entry_maker = function(line)
          if not line or line == '' then
            return nil
          end
          local ok, obj = pcall(vim.fn.json_decode, line)
          if not ok or not obj or not obj.name then
            return nil
          end

          local version = obj.version or 'unknown'
          local display = obj.name .. '  ' .. version

          return {
            value = obj.name,
            display = display,
            ordinal = obj.name,
            name = obj.name,
            latest_version = version,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        -- ENTER → latest_version is already in the entry, no extra API call needed
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          if not entry then
            return
          end
          actions.close(prompt_bufnr)

          local version = entry.latest_version
          if not version or version == 'unknown' then
            vim.notify('Could not determine latest version for ' .. entry.name, vim.log.levels.WARN)
            return
          end

          writer.add_to_pubspec(entry.name, version)
          vim.notify('Added ' .. entry.name .. ' ^' .. version, vim.log.levels.INFO)
        end)

        -- TAB → fetch full version list async, then open version picker
        map('i', '<Tab>', function()
          local entry = action_state.get_selected_entry()
          if not entry then
            return
          end
          actions.close(prompt_bufnr)

          vim.notify('Fetching versions for ' .. entry.name .. '...', vim.log.levels.INFO)
          fetch_versions_async(entry.name, function(versions)
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
          end)
        end)

        return true
      end,
    })
    :find()
end

M.config = config
return M
