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

-- Stores latest version keyed by package name, populated from search results
local latest_version_cache = {}
-- Stores full version list keyed by package name, populated on TAB
local versions_cache = {}

-- Fires off a background job to fetch search JSON and cache latest versions.
-- This runs in parallel with the async job that streams names to telescope.
local function prefetch_latest_versions(prompt)
  local Job = require('plenary.job')
  Job:new({
    command = 'curl',
    args = { '-s', 'https://pub.dev/api/search?q=' .. prompt },
    on_exit = function(j)
      local body = table.concat(j:result(), '\n')
      local ok, data = pcall(vim.fn.json_decode, body)
      if ok and data and data.packages then
        for _, pkg in ipairs(data.packages) do
          if pkg.package and pkg.latest and pkg.latest.version then
            latest_version_cache[pkg.package] = pkg.latest.version
          end
        end
      end
    end,
  }):start()
end

local function fetch_versions_async(name, cb)
  if versions_cache[name] then
    cb(versions_cache[name])
    return
  end

  local Job = require('plenary.job')
  Job:new({
    command = 'curl',
    args = { '-s', 'https://pub.dev/api/packages/' .. name },
    on_exit = function(j)
      local body = table.concat(j:result(), '\n')
      local ok, data = pcall(vim.fn.json_decode, body)
      local versions = {}

      if ok and data and data.versions then
        for i = #data.versions, 1, -1 do
          local v = data.versions[i].version
          if v then
            table.insert(versions, v)
          end
        end
      end

      versions_cache[name] = versions
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
        -- Streams plain package names to telescope (fast, works with async job)
        -- A parallel job also fetches the search JSON to cache latest versions
        command_generator = function(prompt)
          if not prompt or #prompt < 2 then
            return nil
          end
          -- Fire a parallel job to cache latest versions from the same query
          prefetch_latest_versions(prompt)
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
        -- ENTER → use cached latest version (from prefetch), instant
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          if not entry then
            return
          end
          actions.close(prompt_bufnr)

          local version = latest_version_cache[entry.name]
          if not version then
            vim.notify('Could not determine latest version for ' .. entry.name, vim.log.levels.WARN)
            return
          end

          writer.add_to_pubspec(entry.name, version)
          vim.notify('Added ' .. entry.name .. ' ^' .. version, vim.log.levels.INFO)
        end)

        -- TAB → fetch full version list, then open version picker
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
