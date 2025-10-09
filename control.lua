local const = require("const")
local change_group_gui = require("scripts.change_group_gui")
local gui_lib = require("scripts.gui_lib")
require("scripts.space_platform_gui")

script.on_init(function()
  ---@type { [uint32]: PlatformData }
  storage.force_data = {}
  ---@type { [uint32]: PlayerData }
  storage.player_data = {}
end)

script.on_configuration_changed(function(config_changed_data)
  if config_changed_data.mod_changes[const.mod_name] then
    if storage.player_data then
      for index, _ in pairs(storage.player_data) do
        space_platform_gui.destroy(index)
      end
    end
    storage.player_data = {}
  end
end)

script.on_event(defines.events.on_gui_opened, space_platform_gui.on_gui_opened)
script.on_event(defines.events.on_gui_closed, space_platform_gui.on_gui_closed)

script.on_event(const.confirm_gui_id, change_group_gui.on_confirm_gui)
script.on_event(const.focus_search_id, change_group_gui.on_focus_search)

gui_lib.handle_events()
