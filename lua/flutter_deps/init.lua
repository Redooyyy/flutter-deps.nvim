attach_mappings = function(prompt_bufnr, map)
  local entry = action_state.get_selected_entry()
  if not entry then
    return true
  end

  -- ENTER → add latest version
  actions.select_default:replace(function()
    actions.close(prompt_bufnr)
    require('flutter_deps.finder').get_package_info(entry.name, function(info)
      if info and info.latest then
        writer.add_to_pubspec(entry.name, info.latest)
        vim.notify('Added ' .. entry.name .. ' ^' .. info.latest, vim.log.levels.INFO)
      else
        vim.notify('Failed to fetch version for ' .. entry.name, vim.log.levels.ERROR)
      end
    end)
  end)

  -- TAB → show versions
  map('i', '<Tab>', function()
    require('flutter_deps.finder').get_package_info(entry.name, function(info)
      if not info or not info.versions then
        return
      end
      actions.close(prompt_bufnr)

      pickers
        .new({}, {
          prompt_title = 'Select version for ' .. entry.name,
          finder = finders.new_table({
            results = info.versions,
            entry_maker = function(ver)
              return {
                value = ver,
                display = ver,
                ordinal = ver,
              }
            end,
          }),
          sorter = conf.generic_sorter({}),
          attach_mappings = function(ver_bufnr)
            actions.select_default:replace(function()
              local ver_entry = action_state.get_selected_entry()
              actions.close(ver_bufnr)
              writer.add_to_pubspec(entry.name, ver_entry.value)
              vim.notify('Added ' .. entry.name .. ' ^' .. ver_entry.value, vim.log.levels.INFO)
            end)
            return true
          end,
        })
        :find()
    end)
  end)

  return true
end
