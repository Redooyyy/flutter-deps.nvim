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

-- Cache: name -> { latest: string, versions: []string }
local pkg_cache = {}

local function fetch_latest_async(name, cb)
  if pkg_cache[name] and pkg_cache[name].latest then
    cb(pkg_cache[name].latest)
    return
  end

  local Job = require('plenary.job')
  Job:new({
    command = 'sh',
    args = {
      '-c',
      "curl -s 'https://pub.dev/api/packages/" .. name .. "' | jq -r '.latest.version'",
    },
    on_exit = function(j)
      local version = vim.trim(table.concat(j:result(), ''))
      if version == '' or version == 'null' then
        version = nil
      end
      if not pkg_cache[name] then
        pkg_cache[name] = {}
      end
      pkg_cache[name].latest = version
      vim.schedule(function()
        cb(version)
      end)
    end,
  }):start()
end

local function fetch_versions_async(name, cb)
  if pkg_cache[name] and pkg_cache[name].versions then
    cb(pkg_cache[name].versions)
    return
  end

  local Job = require('plenary.job')
  Job:new({
    command = 'sh',
    args = {
      '-c',
      "curl -s 'https://pub.dev/api/packages/"
        .. name
        .. "' | jq -r '[.versions[].version] | reverse[]'",
    },
    on_exit = function(j)
      local versions = {}
      for _, line in ipairs(j:result()) do
        local v = vim.trim(line)
        if v ~= '' and v ~= 'null' then
          table.insert(versions, v)
        end
      end
      if not pkg_cache[name] then
        pkg_cache[name] = {}
      end
      pkg_cache[name].versions = versions
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
        -- ENTER → fetch latest version via jq, add to pubspec
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          if not entry then
            return
          end
          actions.close(prompt_bufnr)

          vim.notify('Fetching ' .. entry.name .. '...', vim.log.levels.INFO)
          fetch_latest_async(entry.name, function(version)
            if not version then
              vim.notify('Could not fetch version for ' .. entry.name, vim.log.levels.WARN)
              return
            end
            writer.add_to_pubspec(entry.name, version)
            vim.notify('Added ' .. entry.name .. ' ^' .. version, vim.log.levels.INFO)
          end)
        end)

        -- TAB → fetch all versions via jq, open version picker
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
