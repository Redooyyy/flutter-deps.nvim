local M = {}
local writer = require('flutter_deps.writer')

local config = {
  keymap = '<leader>pd',
}

local cache = {} -- cache for search results

function M.setup(user_config)
  if user_config then
    for k, v in pairs(user_config) do
      config[k] = v
    end
  end
end

-- fetch full package info (only when needed)
local function fetch_package_info(name, cb)
  vim.fn.jobstart({ 'curl', '-s', 'https://pub.dev/api/packages/' .. name }, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      local body = table.concat(data, '')
      local ok, json = pcall(vim.fn.json_decode, body)
      if ok and json then
        cb(json)
      else
        cb(nil)
      end
    end,
  })
end

-- search pub.dev packages
local function search_pub_dev(prompt, cb)
  if cache[prompt] then
    cb(cache[prompt])
    return
  end

  vim.fn.jobstart({ 'curl', '-s', 'https://pub.dev/api/search?q=' .. prompt }, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      local body = table.concat(data, '')
      local ok, json = pcall(vim.fn.json_decode, body)
      local packages = {}
      if ok and json then
        for _, pkg in ipairs(json.packages or {}) do
          table.insert(packages, pkg.package)
        end
      end
      cache[prompt] = packages
      cb(packages)
    end,
  })
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
          -- we'll handle search in Lua, no shell
          return nil
        end,
        fn = function(prompt, cb)
          search_pub_dev(prompt, function(results)
            local entries = {}
            for _, name in ipairs(results) do
              table.insert(entries, { value = name, display = name, ordinal = name })
            end
            cb(entries)
          end)
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          if not entry then
            return
          end
          actions.close(prompt_bufnr)

          -- fetch package info only on selection
          fetch_package_info(entry.value, function(info)
            local latest_version = (info and info.latest and info.latest.pubspec.version) or 'any'
            writer.add_to_pubspec(entry.value, latest_version)
            vim.schedule(function()
              vim.notify('Added ' .. entry.value .. ' ^' .. latest_version, vim.log.levels.INFO)
            end)
          end)
        end)

        -- optional: version picker on TAB
        map('i', '<Tab>', function()
          local entry = action_state.get_selected_entry()
          if not entry then
            return
          end
          actions.close(prompt_bufnr)

          fetch_package_info(entry.value, function(info)
            if not info or not info.versions then
              return
            end
            local versions = {}
            for i = #info.versions, 1, -1 do
              table.insert(versions, info.versions[i].pubspec.version)
            end

            pickers
              .new({}, {
                prompt_title = 'Select version for ' .. entry.value,
                finder = finders.new_table({ results = versions }),
                sorter = conf.generic_sorter({}),
                attach_mappings = function(bufnr)
                  actions.select_default:replace(function()
                    local ver = action_state.get_selected_entry()
                    actions.close(bufnr)
                    writer.add_to_pubspec(entry.value, ver.value)
                    vim.schedule(function()
                      vim.notify('Added ' .. entry.value .. ' ^' .. ver.value, vim.log.levels.INFO)
                    end)
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
