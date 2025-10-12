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

---@param event EventData.on_gui_checked_state_changed | EventData.on_gui_confirmed | EventData.on_gui_value_changed
local function on_group_parameters_changed(event)
  local player = game.get_player(event.player_index)
  if not player then
    return
  end
  local data = player_data(player.index)
  local group = platform_data.get_group_of_platform(player.force.index, data.platform_index)
  if not group then
    return
  end
  local guis = data.hub_guis

  group.load_limit = guis.loading_checkbox.state and tonumber(guis.loading_text.text) or nil
  group.unload_limit = guis.unloading_checkbox.state and tonumber(guis.unloading_text.text) or nil

  space_platform_gui.update(player.index, data.platform_index)
end

---@param event EventData.on_gui_value_changed
local function on_slider_value_changed(event)
  local guis = player_data(event.player_index).hub_guis
  local new_value = tostring(event.element.slider_value)
  if event.element.name == "loading_slider" then
    -- The game tends to spam these events when dragging a slider.
    if new_value == guis.loading_text.text then
      return
    end
    guis.loading_text.text = new_value
  elseif event.element.name == "unloading_slider" then
    if new_value == guis.unloading_text.text then
      return
    end
    guis.unloading_text.text = new_value
  end
  on_group_parameters_changed(event)
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
            {
              type = "label",
              name = "group_label",
              style = "train_stop_subheader",
              style_mods = { left_padding = 0 },
              tooltip = {
                "?",
                { script.mod_name .. "-description.group-note-tooltip" },
                { "gui-train.train-group-note-tooltip" },
              },
            },
            {
              type = "label",
              name = "group_count_label",
              style = "caption_label",
              tooltip = {
                "?",
                { script.mod_name .. "-name.platforms-in-group" },
                { "gui-train.trains-in-this-group" },
              },
            },
            {
              type = "sprite-button",
              name = "change_group_button",
              style = "mini_button_aligned_to_text_vertically_when_centered",
              sprite = "utility/rename_icon",
              tooltip = { "?", { script.mod_name .. "-name.change-group" }, { "gui-rename.rename-train" } },
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
              type = "flow",
              style = "player_input_horizontal_flow",
              children = {
                {
                  type = "checkbox",
                  name = "loading_checkbox",
                  state = false,
                  caption = { script.mod_name .. "-name.limit-requesting" },
                  tooltip = {
                    script.mod_name .. "-description.limit",
                    { script.mod_name .. "-description.limit-requesting" },
                  },
                  handlers = {
                    [defines.events.on_gui_checked_state_changed] = on_group_parameters_changed,
                  },
                },
                {
                  type = "empty-widget",
                  style_mods = { horizontally_stretchable = true },
                },
                {
                  type = "sprite",
                  name = "loading_status",
                  style = "status_image",
                  resize_to_sprite = false,
                },
              },
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
                  handlers = {
                    [defines.events.on_gui_value_changed] = on_slider_value_changed,
                  },
                },
                {
                  type = "textfield",
                  name = "loading_text",
                  style = "slider_value_textfield",
                  numeric = true,
                  lose_focus_on_confirm = true,
                  handlers = {
                    [defines.events.on_gui_confirmed] = on_group_parameters_changed,
                  },
                },
              },
            },
            {
              type = "flow",
              style = "player_input_horizontal_flow",
              children = {
                {
                  type = "checkbox",
                  name = "unloading_checkbox",
                  state = false,
                  caption = { script.mod_name .. "-name.limit-providing" },
                  tooltip = {
                    script.mod_name .. "-description.limit",
                    { script.mod_name .. "-description.limit-providing" },
                  },
                  handlers = {
                    [defines.events.on_gui_checked_state_changed] = on_group_parameters_changed,
                  },
                },
                {
                  type = "empty-widget",
                  style_mods = { horizontally_stretchable = true },
                },
                {
                  type = "sprite",
                  name = "unloading_status",
                  style = "status_image",
                  resize_to_sprite = false,
                },
              },
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
                  handlers = {
                    [defines.events.on_gui_value_changed] = on_slider_value_changed,
                  },
                },
                {
                  type = "textfield",
                  name = "unloading_text",
                  style = "slider_value_textfield",
                  numeric = true,
                  lose_focus_on_confirm = true,
                  handlers = {
                    [defines.events.on_gui_confirmed] = on_group_parameters_changed,
                  },
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
---@param player_index uint32
---@param platform_index uint32
function space_platform_gui.update(player_index, platform_index)
  local player = game.get_player(player_index)
  if not player then
    return
  end
  local opened = player.opened
  if
    not opened
    or not opened.object_name == "LuaEntity"
    or not opened.surface.platform
    or opened.surface.platform.index ~= platform_index
  then
    return
  end

  local guis = player_data(player.index).hub_guis
  local group = platform_data.get_group_of_platform(player.force.index, platform_index)
  if group == nil then
    guis.group_label.caption = const.no_group
    guis.group_count_label.caption = ""
    guis.group_flow.style.bottom_margin = -8
    guis.control_flow.visible = false
  else
    guis.group_label.caption = group.name
    guis.group_count_label.caption = "[color=" .. const.group_count_color .. "][" .. group.platform_count .. "][/color]"
    guis.group_flow.style.bottom_margin = 0
    guis.control_flow.visible = true

    local load_enabled = group.load_limit ~= nil
    guis.loading_checkbox.state = load_enabled
    guis.loading_slider.enabled = load_enabled
    guis.loading_text.enabled = load_enabled
    local load_value = group.load_limit or 1
    guis.loading_slider.slider_value = load_value
    guis.loading_text.text = tostring(load_value)

    local unload_enabled = group.unload_limit ~= nil
    guis.unloading_checkbox.state = unload_enabled
    guis.unloading_slider.enabled = unload_enabled
    guis.unloading_text.enabled = unload_enabled
    local unload_value = group.unload_limit or 1
    guis.unloading_slider.slider_value = unload_value
    guis.unloading_text.text = tostring(unload_value)

    local load_status = platform_data.get_logistic_status(group, platform_index, "load_limit")
    guis.loading_status.sprite = "utility/status_" .. load_status
    guis.loading_status.tooltip = { script.mod_name .. "-description." .. load_status }
    local unload_status = platform_data.get_logistic_status(group, platform_index, "unload_limit")
    guis.unloading_status.sprite = "utility/status_" .. unload_status
    guis.unloading_status.tooltip = { script.mod_name .. "-description." .. unload_status }

    platform_data.manage_logistics_providers(group)
  end
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
  space_platform_gui.update(event.player_index, space_platform.index)
end

-- Handle the hub GUI closing when we actually wanted to close the
-- change_group_gui.
-- If we had "player.opened" the change_group_gui, it would close the space
-- platform entity GUI, which we do not want. Instead, leave the hub GUI as
-- opened. The downside is that closing with E or Esc closes the hub GUI
-- instead, so this reopenes it right after it closes.
-- Of course, this also fires on a normal close as well.
---@param event EventData.on_gui_closed
function space_platform_gui.on_gui_closed(event)
  local entity = event.entity
  if entity and entity.type == "space-platform-hub" and entity.surface.platform then
    local hub = player_data(event.player_index).opened_hub
    if hub and entity == hub then
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

    platform_data.sync_schedule_from(entity.surface.platform)
  end
end

return space_platform_gui
