---@alias Guis { [string]: LuaGuiElement }

---@class PlayerData
---@field change_group_guis Guis
---@field hub_guis Guis
---@field opened_hub? LuaEntity
---@field last_group? string

-- Get the PlayerData storage table for the specified player.
---@param player_index uint32
---@return PlayerData
---@nodiscard
local function player_data(player_index)
  if not storage.player_data[player_index] then
    storage.player_data[player_index] = {
      change_group_guis = {},
      hub_guis = {},
    }
  end
  return storage.player_data[player_index]
end

return player_data
