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

-- Fetch package info lazily (only called on selection, not during search)
local pkg_info_cache = {}

local function fetch_package_info_async(name, cb)
  if pkg_info_cache[name] then
    cb(pkg_info_cache[name])
    return
  end

  local Job = require('plenary.job')
  Job:new({
    command = 'curl',
    args = { '-s', 'https://pub.dev/api/packages/' .. name },
    on_exit = function(j)
      local body = table.concat(j:result(), '\n')
      local ok, data = pcall(vim.fn.json_decode, body)
      local result = (ok and data) and data or nil
      pkg_info_cache[name] = result
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
        -- entry_maker is now instant: no network calls, just pass the name through
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
        -- ENTER → fetch info async, then add latest version
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          if not entry then
            return
          end
          actions.close(prompt_bufnr)

          vim.notify('Fetching info for ' .. entry.name .. '...', vim.log.levels.INFO)
          fetch_package_info_async(entry.name, function(info)
            local latest = info and info.latest and info.latest.pubspec.version or 'any'
            writer.add_to_pubspec(entry.name, latest)
            vim.notify('Added ' .. entry.name .. ' ^' .. latest, vim.log.levels.INFO)
          end)
        end)

        -- TAB → fetch info async, then open version picker
        map('i', '<Tab>', function()
          local entry = action_state.get_selected_entry()
          if not entry then
            return
          end
          actions.close(prompt_bufnr)

          vim.notify('Fetching versions for ' .. entry.name .. '...', vim.log.levels.INFO)
          fetch_package_info_async(entry.name, function(info)
            local all_versions = info and info.versions or {}

            -- reverse so latest comes first
            local versions = {}
            for i = #all_versions, 1, -1 do
              table.insert(versions, all_versions[i].pubspec.version)
            end

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
