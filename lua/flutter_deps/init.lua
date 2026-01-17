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

local function fetch_latest_version(name, cb)
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
      if ok and data and data.latest and data.latest.pubspec.version then
        local latest = data.latest.pubspec.version
        package_cache[name] = latest
        vim.schedule(function()
          cb(latest)
        end)
      else
        vim.schedule(function()
          cb('unknown')
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
          local display = line .. ' — loading...'
          local entry = {
            value = line,
            display = display,
            ordinal = line,
            name = line,
            latest_version = 'loading...',
          }

          -- async fetch latest version
          fetch_latest_version(line, function(ver)
            entry.latest_version = ver
            entry.display = line .. ' — ' .. ver
          end)

          return entry
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

          if entry.latest_version == 'loading...' or entry.latest_version == 'unknown' then
            vim.notify('Still fetching version for ' .. entry.name .. '...', vim.log.levels.WARN)
            return
          end

          writer.add_to_pubspec(entry.name, entry.latest_version)
          vim.notify('Added ' .. entry.name .. ' ^' .. entry.latest_version, vim.log.levels.INFO)
        end)
        return true
      end,
    })
    :find()
end

M.config = config
return M
