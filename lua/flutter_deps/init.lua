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

-- Helper: fetch package info from pub.dev
local function fetch_package_info(name)
  local body = vim.fn.system('curl -s https://pub.dev/api/packages/' .. name)
  local ok, data = pcall(vim.fn.json_decode, body)
  if ok and data then
    return data
  end
  return nil
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
          local info = fetch_package_info(line)
          local latest_version = info and info.latest and info.latest.pubspec.version or 'any'
          return {
            value = line,
            display = line,
            ordinal = line,
            name = line,
            latest_version = latest_version,
            all_versions = info and info.versions or {},
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
          writer.add_to_pubspec(entry.name, entry.latest_version)
          vim.notify('Added ' .. entry.name .. ' ^' .. entry.latest_version, vim.log.levels.INFO)
        end)

        -- TAB → choose version
        map('i', '<Tab>', function()
          local entry = action_state.get_selected_entry()
          if not entry or not entry.all_versions then
            return
          end
          actions.close(prompt_bufnr)

          pickers
            .new({}, {
              prompt_title = 'Select version for ' .. entry.name,
              finder = finders.new_table({
                results = vim.tbl_map(function(v)
                  return v.pubspec.version
                end, entry.all_versions),
              }),
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

        return true
      end,
    })
    :find()
end

M.config = config
return M
