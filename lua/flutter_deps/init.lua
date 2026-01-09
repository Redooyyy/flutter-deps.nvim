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

  -- Ask user for query
  local query = vim.fn.input('Search pub.dev package: ')

  if query == '' then
    print('No package name provided')
    return
  end

  -- Fetch matching packages
  local results = finder.search(query)

  if #results == 0 then
    print('No results found for: ' .. query)
    return
  end

  local selection

  if config.use_telescope then
    local has_telescope, telescope = pcall(require, 'telescope')
    if not has_telescope then
      print('Telescope not found! Showing first result')
      selection = results[1]
    else
      local pickers = require('telescope.pickers')
      local finders = require('telescope.finders')
      local conf = require('telescope.config').values
      local actions = require('telescope.actions')
      local action_state = require('telescope.actions.state')

      pickers
        .new({}, {
          prompt_title = 'Pub.dev Packages',
          finder = finders.new_table({
            results = results,
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
              selection = action_state.get_selected_entry().value
              actions.close(prompt_bufnr)
            end)
            return true
          end,
        })
        :find()
    end
  else
    -- Just pick the first one if Telescope is disabled
    selection = results[1]
  end

  if selection then
    writer.add_to_pubspec(selection.name, selection.latest_version)
    print('Added ' .. selection.name .. '@' .. selection.latest_version .. ' to pubspec.yaml')
  end
end

M.config = config

return M
