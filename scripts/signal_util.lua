local signal_util = {}

-- Convert a SignalFilter to an ElemID, used in LuaGuiElements for smart
-- tooltips.
---@param filter SignalFilter
---@return ElemID
---@nodiscard
function signal_util.to_elem_id(filter)
  ---@type string
  local signal_type = filter.type
  if signal_type == "virtual" then
    signal_type = "signal"
  elseif signal_type == "item" then
    signal_type = "item-with-quality"
  elseif signal_type == "entity" then
    signal_type = "entity-with-quality"
  elseif signal_type == "recipe" then
    signal_type = "recipe-with-quality"
  end
  return {
    type = signal_type,
    signal_type = signal_type == "signal" and filter.type or nil,
    name = filter.name,
    quality = filter.quality,
  }
end

-- Convert a SignalFilter to a SpritePath, used in LuaGuiElements for loading
-- sprites.
---@param filter SignalFilter
---@return SpritePath
---@nodiscard
function signal_util.to_sprite_path(filter)
  ---@type string
  local signal_type = filter.type
  if signal_type == "virtual" then
    signal_type = "virtual-signal"
  end
  return signal_type .. "/" .. filter.name
end

-- Convert a SignalFilter to a LuaPrototypeBase subclass, used to lookup the
-- localised_name of the prototype.
---@param filter SignalFilter
---@return LuaPrototypeBase
---@nodiscard
function signal_util.to_prototype(filter)
  ---@type string
  local signal_type = filter.type
  if signal_type == "virtual" then
    signal_type = "virtual_signal"
  elseif signal_type == "space-location" then
    signal_type = "space_location"
  elseif signal_type == "asteroid-chunk" then
    signal_type = "asteroid_chunk"
  end
  return prototypes[signal_type][filter.name]
end

return signal_util
