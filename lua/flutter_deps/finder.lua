function M.get_package_info(name, cb)
  Job
    :new({
      command = 'curl',
      args = { '-s', 'https://pub.dev/api/packages/' .. name },
      on_exit = function(j)
        local body = table.concat(j:result(), '\n')
        local ok, data = pcall(vim.fn.json_decode, body)
        if ok and data then
          local latest = data.latest and data.latest.pubspec and data.latest.pubspec.version
            or 'any'
          local versions = {}
          if data.versions then
            for _, v in ipairs(data.versions) do
              table.insert(versions, v.version)
            end
          end
          vim.schedule(function()
            cb({ latest = latest, versions = versions })
          end)
        else
          vim.schedule(function()
            cb(nil)
          end)
        end
      end,
    })
    :start()
end
