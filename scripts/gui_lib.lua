-- Copied and brutally modified from:
-- https://codeberg.org/raiguard/flib/src/branch/trunk/gui.lua
-- Mostly greatly simplified to remove parts that are not needed, and to stop pointless warnings.

-- A GUI element definition. This extends `LuaGuiElement.add_param` with several new attributes.
---@class GuiElemDef: LuaGuiElement.add_param.button|LuaGuiElement.add_param.camera|LuaGuiElement.add_param.checkbox|LuaGuiElement.add_param.choose_elem_button|LuaGuiElement.add_param.drop_down|LuaGuiElement.add_param.flow|LuaGuiElement.add_param.frame|LuaGuiElement.add_param.line|LuaGuiElement.add_param.list_box|LuaGuiElement.add_param.minimap|LuaGuiElement.add_param.progressbar|LuaGuiElement.add_param.radiobutton|LuaGuiElement.add_param.scroll_pane|LuaGuiElement.add_param.slider|LuaGuiElement.add_param.sprite|LuaGuiElement.add_param.sprite_button|LuaGuiElement.add_param.switch|LuaGuiElement.add_param.tab|LuaGuiElement.add_param.table|LuaGuiElement.add_param.text_box|LuaGuiElement.add_param.textfield
---@field alias string? Other name to save the element in the `elems` table by.
---@field style_mods LuaStyle|table<string, any>? Modifications to make to the element's style.
---@field elem_mods LuaGuiElement|table<string, any>? Modifications to make to the element itself.
---@field drag_target string? Set the element's drag target to the element whose name matches this string. The drag target must be present in the `elems` table.
---@field handlers table<defines.events, GuiElemHandler>? Handlers to assign to this element. If assigned to a function, that function will be called for any GUI event on this element.
---@field children GuiElemDef|GuiElemDef[]? Children to add to this element.

-- A handler function to invoke when receiving GUI events for this element.
---@alias GuiElemHandler fun(e: GuiEventData)

-- Aggregate type of all possible GUI events.
---@alias GuiEventData
---|EventData.on_gui_checked_state_changed
---|EventData.on_gui_click
---|EventData.on_gui_closed
---|EventData.on_gui_confirmed
---|EventData.on_gui_elem_changed
---|EventData.on_gui_location_changed
---|EventData.on_gui_opened
---|EventData.on_gui_selected_tab_changed
---|EventData.on_gui_selection_state_changed
---|EventData.on_gui_switch_state_changed
---|EventData.on_gui_text_changed
---|EventData.on_gui_value_changed

local handler_tag_key = "__" .. script.mod_name .. "_handlers"
---@type table<string, GuiElemHandler>
local handlers_lookup = {}

local gui_lib = {}

-- Add a new child or children to the given GUI element.
---@param parent LuaGuiElement The parent GUI element.
---@param def GuiElemDef|GuiElemDef[] The element definition, or an array of element definitions.
---@param elems table<string, LuaGuiElement>? Optional initial `elems` table.
---@return table<string, LuaGuiElement> elems Elements with names will be collected into this table.
---@return LuaGuiElement first The element that was created first;  the "top level" element.
function gui_lib.add(parent, def, elems)
  if not elems then
    elems = {}
  end
  -- If a single def was passed, wrap it in an array
  if def.type then
    def = { def }
  end
  local first
  for i = 1, #def do
    local def = def[i]
    if def.type then
      -- Remove custom attributes from the def so the game doesn't serialize them
      local alias = def.alias
      local children = def.children
      local elem_mods = def.elem_mods
      local handlers = def.handlers
      local style_mods = def.style_mods
      local drag_target = def.drag_target
      def.alias = nil
      def.children = nil
      def.elem_mods = nil
      def.handlers = nil
      def.style_mods = nil
      def.drag_target = nil

      local elem = parent.add(def)

      if not first then
        first = elem
      end
      if def.name then
        elems[def.name] = elem
      end
      if alias then
        elems[alias] = elem
      end
      if style_mods then
        for key, value in pairs(style_mods) do
          elem.style[key] = value
        end
      end
      if elem_mods then
        for key, value in pairs(elem_mods) do
          elem[key] = value
        end
      end
      if drag_target then
        local target = elems[drag_target]
        if not target then
          error("Drag target '" .. drag_target .. "' not found.")
        end
        elem.drag_target = target
      end
      if handlers then
        local out = {}
        for name, handler in pairs(handlers) do
          out[tostring(name)] = true
          handlers_lookup[def.name .. tostring(name)] = handler
        end
        local tags = elem.tags
        tags[handler_tag_key] = out
        elem.tags = tags
      end
      if children then
        gui_lib.add(elem, children, elems)
      end

      -- Re-add custom attributes for table reuse.
      def.alias = alias
      def.children = children
      def.elem_mods = elem_mods
      def.handlers = handlers
      def.style_mods = style_mods
      def.drag_target = drag_target
    end
  end
  return elems, first
end

-- Dispatch the handler associated with this event and GUI element.
---@param event GuiEventData
local function dispatch(event)
  local element = event.element
  if not element then
    return
  end
  local tags = element.tags
  local handlers = tags[handler_tag_key]
  if handlers and handlers[tostring(event.name)] then
    local handler = handlers_lookup[element.name .. tostring(event.name)]
    if handler then
      handler(event)
    end
  end
end

function gui_lib.handle_events()
  for name, id in pairs(defines.events) do
    if string.find(name, "on_gui_") then
      if not script.get_event_handler(id) then
        script.on_event(id, dispatch)
      end
    end
  end
end

return gui_lib
