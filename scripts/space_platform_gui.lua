local change_group_gui = require("scripts.change_group_gui")
local const = require("const")
local gui_lib = require("scripts.gui_lib")
local platform_data = require("scripts.platform_data")
local player_data = require("scripts.player_data")

space_platform_gui = {}

local anchor = { gui = defines.relative_gui_type.space_platform_hub_gui, position = defines.relative_gui_position.top }

-- Return if the GUI still exists.
---@param guis Guis
---@return boolean
---@nodiscard
function space_platform_gui.valid(guis)
  return guis.root and guis.root.valid
end

-- Destroy this GUI if it exists.
---@param player_index uint32
function space_platform_gui.destroy(player_index)
  local data = player_data(player_index)
  local guis = data.hub_guis
  if space_platform_gui.valid(guis) then
    guis.root.destroy()
  end
  data.hub_guis = {}
end

---@param event EventData.on_gui_click
local function on_edit_button_clicked(event)
  local player = game.get_player(event.player_index)
  if player then
    local data = player_data(event.player_index)
    data.opened_hub = player.opened --[[@as LuaEntity]]
    local group = platform_data.get_group_of_platform(player.force.index, data.platform_index)
    change_group_gui.build(player, event.cursor_display_location, group and group.name or nil)
  end
end

-- Build the side frame on a space platform hub GUI for showing the group.
---@param player LuaPlayer
function space_platform_gui.build(player)
  space_platform_gui.destroy(player.index)

  local data = player_data(player.index)
  data.hub_guis = gui_lib.add(player.gui.relative, {
    type = "frame",
    name = script.mod_name .. "_hub_group_root",
    alias = "root",
    style = "slot_window_frame",
    anchor = anchor,
    children = {
      type = "frame",
      style = "inside_shallow_frame_with_padding",
      direction = "vertical",
      style_mods = {
        horizontally_stretchable = false,
      },
      children = {
        {
          type = "flow",
          name = "group_flow",
          style = "player_input_horizontal_flow",
          style_mods = {
            horizontal_spacing = 4,
            top_margin = -8,
          },
          children = {
            { type = "label", name = "group_label", style = "train_stop_subheader", style_mods = { left_padding = 0 } },
            {
              type = "label",
              name = "group_count_label",
              style = "caption_label",
              caption = { "?", { script.mod_name .. ".platforms-in-this-group" }, { "gui-train.trains-in-this-group" } },
            },
            {
              type = "sprite-button",
              name = "change_group_button",
              style = "mini_button_aligned_to_text_vertically_when_centered",
              sprite = "utility/rename_icon",
              tooltip = { "?", { script.mod_name .. ".change-group" }, { "gui-rename.rename-train" } },
              handlers = {
                [defines.events.on_gui_click] = on_edit_button_clicked,
              },
            },
          },
        },
        {
          type = "flow",
          name = "control_flow",
          direction = "vertical",
          children = {
            {
              type = "checkbox",
              name = "loading_checkbox",
              state = false,
              caption = "Limit loading TODO",
            },
            {
              type = "flow",
              style = "player_input_horizontal_flow",
              children = {
                {
                  type = "slider",
                  name = "loading_slider",
                  style = "notched_slider",
                  maximum_value = 5,
                  value = 1,
                },
                {
                  type = "textfield",
                  name = "loading_text",
                  style = "slider_value_textfield",
                  numeric = true,
                  lose_focus_on_confirm = true,
                },
              },
            },
            {
              type = "checkbox",
              name = "unloading_checkbox",
              state = false,
              caption = "Limit unloading TODO",
            },
            {
              type = "flow",
              style = "player_input_horizontal_flow",
              children = {
                {
                  type = "slider",
                  name = "unloading_slider",
                  style = "notched_slider",
                  maximum_value = 5,
                  value = 1,
                },
                {
                  type = "textfield",
                  name = "unloading_text",
                  style = "slider_value_textfield",
                  numeric = true,
                  lose_focus_on_confirm = true,
                },
              },
            },
          },
        },
      },
    },
  })
end

-- Update the displayed group name in the already built GUI.
---@param player LuaPlayer
---@param platform_index uint32
function space_platform_gui.update(player, platform_index)
  local guis = player_data(player.index).hub_guis
  local group = platform_data.get_group_of_platform(player.force.index, platform_index)
  guis.group_label.caption = group and group.name or const.no_group
  guis.group_count_label.caption = group
      and "[color=" .. const.group_count_color .. "][" .. group.platform_count .. "][/color]"
    or ""
  guis.control_flow.visible = group ~= nil
  guis.group_flow.style.bottom_margin = group == nil and -8 or 0
end

---@param event EventData.on_gui_opened
function space_platform_gui.on_gui_opened(event)
  local entity = event.entity
  if event.gui_type ~= defines.gui_type.entity then
    return
  end
  if not entity or not entity.valid or entity.type ~= "space-platform-hub" then
    return
  end
  local space_platform = entity.surface.platform
  if not space_platform then
    return
  end
  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  local data = player_data(event.player_index)
  data.platform_index = space_platform.index
  if not space_platform_gui.valid(data.hub_guis) then
    space_platform_gui.build(player)
  end
  space_platform_gui.update(player, space_platform.index)
end

-- Handle the hub GUI closing when we actually wanted to close the
-- change_group_gui.
-- If we had "player.opened" the change_group_gui, it would close the space
-- platform entity GUI, which we do not want. Instead, leave the hub GUI as
-- opened. The downside is that closing with E or Esc closes the hub GUI
-- instead, so this reopenes it right after it closes.
---@param event EventData.on_gui_closed
function space_platform_gui.on_gui_closed(event)
  local hub = player_data(event.player_index).opened_hub
  if hub and event.entity and event.entity == hub then
    change_group_gui.destroy(event.player_index)
    local player = game.get_player(event.player_index)
    -- If anything else was opened, we don't want to override that.
    if player and player.opened == nil then
      player.opened = hub
    end
  else
    space_platform_gui.destroy(event.player_index)
  end
  player_data(event.player_index).opened_hub = nil
end

return space_platform_gui
