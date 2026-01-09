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
            'curl',
            '-s',
            'https://pub.dev/api/search?q=' .. prompt,
          }
        end,

        entry_maker = function(line)
          local ok, data = pcall(vim.fn.json_decode, line)
          if not ok or not data.packages then
            return nil
          end

          local entries = {}
          for _, pkg in ipairs(data.packages) do
            table.insert(entries, {
              value = pkg,
              display = pkg.package,
              ordinal = pkg.package,
              name = pkg.package,
              latest_version = pkg.version or 'latest',
            })
          end

          return entries
        end,
      }),

      sorter = conf.generic_sorter({}),

      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          if not selection then
            return
          end

          actions.close(prompt_bufnr)
          writer.add_to_pubspec(selection.name, selection.latest_version)

          vim.notify(
            'Added ' .. selection.name .. '@' .. selection.latest_version,
            vim.log.levels.INFO
          )
        end)

        return true
      end,
    })
    :find()
end

M.config = config
return M
