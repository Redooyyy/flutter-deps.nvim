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
  local writer = require('flutter_deps.writer')

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
            table.concat({
              "curl -s 'https://pub.dev/api/search?q=" .. prompt .. "'",
              "| jq -r '.packages[].package'",
            }, ' '),
          }
        end,

        entry_maker = function(line)
          return {
            value = line,
            display = line,
            ordinal = line,
            name = line,
            latest_version = 'any',
          }
        end,
      }),

      sorter = conf.generic_sorter({}),

      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          if not entry then
            return
          end

          actions.close(prompt_bufnr)
          writer.add_to_pubspec(entry.name, entry.latest_version)

          vim.notify('Added ' .. entry.name, vim.log.levels.INFO)
        end)

        return true
      end,
    })
    :find()
end

M.config = config
return M
