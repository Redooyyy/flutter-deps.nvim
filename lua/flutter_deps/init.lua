local M = {}

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

function M.add_dependency()
  local finder = require('flutter_deps.finder')
  local writer = require('flutter_deps.writer')

  local has_telescope, telescope = pcall(require, 'telescope')
  if not has_telescope then
    print('Telescope.nvim is required')
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
      finder = finders.new_dynamic({
        fn = function(input, cb)
          finder.debounced_search(input, cb)
        end,
        entry_maker = function(entry)
          return {
            value = entry,
            display = entry.name .. ' [' .. entry.latest_version .. ']',
            ordinal = entry.name,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry().value
          actions.close(prompt_bufnr)
          writer.add_to_pubspec(selection.name, selection.latest_version)
          print('Added ' .. selection.name .. '@' .. selection.latest_version)
        end)
        return true
      end,
    })
    :find()
end

M.config = config
return M
