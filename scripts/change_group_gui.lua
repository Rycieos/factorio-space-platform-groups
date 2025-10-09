local const = require("const")
local player_data = require("scripts.player_data")
local space_platform_gui = require("scripts.space_platform_gui")

change_group_gui = {}

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
  guis.root = nil
  guis.overlay = nil
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
    else
      toggle_search_box(guis)
    end
  end
end

---@param event EventData.on_gui_click
local function on_search_button_click(event)
  toggle_search_box(player_data(event.player_index).change_group_guis)
end

---@param event EventData.on_gui_click
local function on_close_button_click(event)
  change_group_gui.destroy(event.player_index)
end

-- Build a popup GUI for selecting a group.
---@param player LuaPlayer
---@param selected_group LocalisedString
---@param cursor_location GuiLocation
function change_group_gui.build(player, selected_group, cursor_location)
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
    style = "inset_frame_container_frame",
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
    },
  }, data.change_group_guis)
end

-- When recieved our custom confirming event.
-- This happens on `E` press, and `space_platform_gui.on_gui_close()` will fire
-- at the same time.
---@param event EventData.CustomInputEvent
function change_group_gui.on_confirm_gui(event)
  guis = player_data(event.player_index).change_group_guis
  if change_group_gui.valid(guis) then
    -- TODO save something
    log("saved group")
    change_group_gui.destroy(event.player_index)
  end
end

return change_group_gui
