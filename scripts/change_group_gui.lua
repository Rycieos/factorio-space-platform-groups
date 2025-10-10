local const = require("const")
local gui_lib = require("scripts.gui_lib")
local platform_data = require("scripts.platform_data")
local player_data = require("scripts.player_data")

local change_group_gui = {}

-- Return if the GUI still exists.
---@param guis Guis
---@return boolean
---@nodiscard
function change_group_gui.valid(guis)
  return guis.root and guis.root.valid
end

-- Destroy this GUI if it exists.
---@param player_index uint
function change_group_gui.destroy(player_index)
  local data = player_data(player_index)
  local guis = data.change_group_guis
  if change_group_gui.valid(guis) then
    guis.root.destroy()
  end
  if guis.overlay and guis.overlay.valid then
    guis.overlay.destroy()
  end
  data.change_group_guis = {}
end

-- Show or hide the search box.
---@param guis Guis
local function toggle_search_box(guis)
  -- Poor man's overlay textbox.
  if guis.search_box.visible then
    guis.search_box.visible = false
    guis.search_box.text = ""
    -- The above line does not trigger an event.
    --search.update_search_results(guis)
    guis.search_button.toggled = false
    guis.frame_label.style.maximal_width = guis.frame_label.style.maximal_width + 110
  else
    guis.search_box.visible = true
    guis.search_box.focus()
    guis.search_button.toggled = true
    guis.frame_label.style.maximal_width = guis.frame_label.style.maximal_width - 110
  end
end

---@param event EventData.CustomInputEvent
function change_group_gui.on_focus_search(event)
  local guis = player_data(event.player_index).change_group_guis
  if change_group_gui.valid(guis) then
    if guis.search_box.visible then
      guis.search_box.select_all()
      guis.search_box.focus()
    else
      toggle_search_box(guis)
    end
  end
end

---@param event EventData.on_gui_click
local function on_search_button_click(event)
  toggle_search_box(player_data(event.player_index).change_group_guis)
end

---@param event EventData.on_gui_click | EventData.on_gui_confirmed
local function on_close_button_click(event)
  local data = player_data(event.player_index)
  data.opened_hub = nil
  -- In the "normal" case, closing this GUI happens when the Hub GUI closes (and
  -- is then reopened immediately), so we don't need to update the Hub GUI as it
  -- will be updated when it opens. But in this case it is not closed (hence the
  -- clearing of the field above), so we need to manually update it.
  space_platform_gui.update(event.player_index, data.platform_index)
  change_group_gui.destroy(event.player_index)
end

-- When recieved our custom confirming event.
-- This happens on `E` press, and `space_platform_gui.on_gui_close()` will fire
-- at the same time.
-- This will also fire on `E` press when the icon selector is open, so don't
-- close this GUI.
---@param event EventData.CustomInputEvent | EventData.on_gui_click | EventData.on_gui_confirmed
function change_group_gui.on_confirm_gui(event)
  local data = player_data(event.player_index)
  if change_group_gui.valid(data.change_group_guis) then
    local player = game.get_player(event.player_index)
    if player and data.platform_index then
      local group_name = data.change_group_guis.group_name_box.text
      if group_name and group_name ~= "" then
        platform_data.add_platform_to_group(
          player.force.index,
          data.change_group_guis.group_name_box.text,
          data.platform_index
        )
      else
        platform_data.remove_platform(player.force.index, data.platform_index)
      end
    end
  end
end

---@param event EventData.on_gui_click | EventData.on_gui_confirmed
local function on_confirm(event)
  change_group_gui.on_confirm_gui(event)
  on_close_button_click(event)
end

---@param event EventData.on_gui_text_changed
local function on_group_text_changed(event)
  event.element.no_group_placeholder.visible = event.text == ""
end

---@param event EventData.on_gui_click
local function on_list_item_click(event)
  local guis = player_data(event.player_index).change_group_guis
  local button = event.element
  if button == guis.no_group_button then
    guis.group_name_box.text = ""
    guis.no_group_placeholder.visible = true
  else
    guis.group_name_box.text = button.caption --[[@as string]]
    guis.no_group_placeholder.visible = false
  end

  for _, button in pairs(guis.groups_list.children) do
    button.toggled = false
  end
  button.toggled = true
end

-- Build a popup GUI for selecting a group.
---@param player LuaPlayer
---@param cursor_location GuiLocation
---@param selected_group? string
function change_group_gui.build(player, cursor_location, selected_group)
  change_group_gui.destroy(player.index)

  local data = player_data(player.index)

  local resolution = player.display_resolution
  local scale = player.display_scale
  local overlay_size = { resolution.width / scale, resolution.height / scale }

  -- A full screen transparent element that will close the main window if it is
  -- clicked off of.
  data.change_group_guis = gui_lib.add(player.gui.screen, {
    type = "empty-widget",
    name = script.mod_name .. "_change_group_cover",
    alias = "overlay",
    style_mods = { size = overlay_size },
    handlers = { [defines.events.on_gui_click] = on_close_button_click },
  })

  gui_lib.add(player.gui.screen, {
    type = "frame",
    name = script.mod_name .. "_change_group_root",
    alias = "root",
    direction = "vertical",
    style = const.vertical_container_frame,
    style_mods = {
      minimal_height = 218,
      width = 400,
    },
    elem_mods = {
      location = cursor_location,
    },
    children = {
      {
        type = "flow",
        style = "frame_header_flow",
        drag_target = "root",
        children = {
          {
            type = "label",
            name = "frame_label",
            style = "frame_title",
            style_mods = {
              bottom_padding = 3,
              top_margin = -3,
              maximal_width = 300,
            },
            caption = { script.mod_name .. ".change-group" },
            drag_target = "root",
          },
          {
            type = "empty-widget",
            style = "draggable_space_header",
            style_mods = {
              height = 24,
              horizontally_stretchable = true,
            },
            drag_target = "root",
          },
          {
            type = "textfield",
            name = "search_box",
            style = "search_popup_textfield",
            visible = false,
          },
          {
            type = "sprite-button",
            name = "search_button",
            style = "frame_action_button",
            sprite = "utility/search",
            tooltip = { "gui.search-with-focus", "__CONTROL__focus-search__" },
            handlers = {
              [defines.events.on_gui_click] = on_search_button_click,
            },
          },
          {
            type = "sprite-button",
            name = "close_button",
            style = "frame_action_button",
            sprite = "utility/close",
            tooltip = { "gui.close-instruction" },
            handlers = {
              [defines.events.on_gui_click] = on_close_button_click,
            },
          },
        },
      },
      {
        type = "frame",
        direction = "vertical",
        style = "inside_deep_frame",
        style_mods = {
          vertically_stretchable = true,
        },
        children = {
          {
            type = "frame",
            style = "subheader_frame",
            children = {
              {
                type = "textfield",
                name = "group_name_box",
                style_mods = {
                  horizontally_stretchable = true,
                  maximal_width = 0,
                },
                icon_selector = true,
                text = selected_group,
                handlers = {
                  [defines.events.on_gui_confirmed] = on_confirm,
                  [defines.events.on_gui_text_changed] = on_group_text_changed,
                },
                children = {
                  type = "label",
                  name = "no_group_placeholder",
                  style_mods = { font_color = { 0, 0, 0, 0.4 } },
                  caption = const.no_group,
                  ignored_by_interaction = true,
                  visible = selected_group == nil,
                },
              },
              {
                type = "sprite-button",
                name = "confirm_button",
                style = "item_and_count_select_confirm",
                sprite = "utility/confirm_slot",
                handlers = {
                  [defines.events.on_gui_click] = on_confirm,
                },
              },
            },
          },
          {
            type = "scroll-pane",
            name = "groups_list",
            direction = "vertical",
            style = const.scroll_pane,
            children = {
              type = "button",
              name = "no_group_button",
              style = "list_box_item",
              style_mods = {
                horizontally_stretchable = true,
              },
              caption = const.no_group,
              handlers = {
                [defines.events.on_gui_click] = on_list_item_click,
              },
            },
          },
        },
      },
    },
  }, data.change_group_guis)

  data.change_group_guis.group_name_box.focus()

  local groups_list_box = data.change_group_guis.groups_list
  local groups = platform_data.get_groups(player.force.index)
  for i, group in pairs(groups) do
    gui_lib.add(groups_list_box, {
      type = "button",
      name = "group_button_" .. i,
      style = "list_box_item",
      style_mods = {
        horizontally_stretchable = true,
      },
      caption = group.name,
      handlers = {
        [defines.events.on_gui_click] = on_list_item_click,
      },
      children = {
        type = "flow",
        direction = "vertical",
        style_mods = {
          natural_width = 354,
          horizontal_align = "right",
        },
        ignored_by_interaction = true,
        children = {
          type = "label",
          caption = tostring(group.platform_count),
        },
      },
    })
  end
end

return change_group_gui
