local M = {}

-- Default config
local config = {
  keymap = '<leader>pd', -- default keymap
  use_telescope = true, -- use Telescope picker
}

function M.setup(user_config)
  if user_config then
    for k, v in pairs(user_config) do
      config[k] = v
    end
  end
end

-- Add dependency workflow
function M.add_dependency()
  local finder = require('flutter_deps.finder')
  local writer = require('flutter_deps.writer')

  local has_telescope, telescope = pcall(require, 'telescope')
  if not has_telescope then
    print('Telescope.nvim is required for this plugin')
    return
  end

  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')

  -- Open Telescope directly with a dynamic finder
  pickers
    .new({}, {
      prompt_title = 'Search pub.dev packages',
      finder = finders.new_dynamic({
        fn = function(input)
          if input == '' then
            return {}
          end
          return finder.search(input) -- search pub.dev dynamically as user types
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
