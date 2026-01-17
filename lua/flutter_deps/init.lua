local M = {}
local writer = require('flutter_deps.writer')
local Job = require('plenary.job')

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

-- Cache for package info
local package_cache = {}

local function fetch_package_info(name, cb)
  if package_cache[name] then
    cb(package_cache[name])
    return
  end

  Job:new({
    command = 'curl',
    args = { '-s', 'https://pub.dev/api/packages/' .. name },
    on_exit = function(j)
      local body = table.concat(j:result(), '\n')
      local ok, data = pcall(vim.fn.json_decode, body)
      if ok and data then
        -- reverse versions: latest first
        if data.versions then
          local reversed = {}
          for i = #data.versions, 1, -1 do
            table.insert(reversed, data.versions[i])
          end
          data.versions = reversed
        end
        package_cache[name] = data
        vim.schedule(function()
          cb(data)
        end)
      else
        vim.schedule(function()
          cb(nil)
        end)
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
          return {
            'sh',
            '-c',
            "curl -s 'https://pub.dev/api/search?q=" .. prompt .. "' | jq -r '.packages[].package'",
          }
        end,
        entry_maker = function(line)
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
        -- ENTER → add latest version
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          if not entry then
            return
          end
          actions.close(prompt_bufnr)

          vim.notify('Fetching latest version for ' .. entry.name .. '...')

          fetch_package_info(entry.name, function(info)
            if info and info.latest and info.latest.pubspec.version then
              local latest = info.latest.pubspec.version
              writer.add_to_pubspec(entry.name, latest)
              vim.notify('Added ' .. entry.name .. ' ^' .. latest, vim.log.levels.INFO)
            else
              vim.notify('Failed to fetch version for ' .. entry.name, vim.log.levels.ERROR)
            end
          end)
        end)

        -- TAB → show versions with loading animation
        map('i', '<Tab>', function()
          local entry = action_state.get_selected_entry()
          if not entry then
            return
          end
          actions.close(prompt_bufnr)

          vim.notify('Fetching versions for ' .. entry.name .. '...')

          -- temporary "loading..." picker
          local loading_picker = pickers.new({}, {
            prompt_title = 'Versions for ' .. entry.name,
            finder = finders.new_table({ results = { 'loading......' } }),
            sorter = conf.generic_sorter({}),
          })
          loading_picker:find()

          fetch_package_info(entry.name, function(info)
            if not info or not info.versions then
              vim.notify('No versions found for ' .. entry.name, vim.log.levels.ERROR)
              return
            end

            local versions = vim.tbl_map(function(v)
              return v.version
            end, info.versions)

            -- reopen picker with real versions
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
