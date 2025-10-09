local const = require("const")

local platform_data = {}

---@class PlatformGroup
---@field name string
---@field platforms { [uint32]: LuaSpacePlatform }
---@field platform_count uint32
---@field platform_count_string function
---@field load_limit? uint8
---@field unload_limit? uint8

---@class PlatformData
---@field groups { [string]: PlatformGroup }
---@field platforms { [uint32]: PlatformGroup }

-- Get the PlatformData storage table for the specified Force.
---@param force_index uint32
---@return PlatformData
---@nodiscard
function platform_data.raw(force_index)
  if not storage.force_data[force_index] then
    storage.force_data[force_index] = {
      groups = {},
      platforms = {},
    }
  end
  return storage.force_data[force_index]
end

-- Return the platform_count formatted for printing in a label.
---@param self PlatformGroup
---@return string
---@nodiscard
local function platform_count_string(self)
  return "[color=" .. const.group_count_color .. "][" .. self.platform_count .. "][/color]"
end

-- Get the PlatformGroup by the name, creating it if it does not exist.
---@param force_index uint32
---@param group_name string
---@return PlatformGroup
function platform_data.get_or_create_group(force_index, group_name)
  local data = platform_data.raw(force_index)
  if not data.groups[group_name] then
    data.groups[group_name] = {
      name = group_name,
      platforms = {},
      platform_count = 0,
      platform_count_string = platform_count_string,
    }
  end
  return data.groups[group_name]
end

-- Rename the group from old_group_name to new_group_name.
---@param force_index uint32
---@param old_group_name string
---@param new_group_name string
function platform_data.rename_group(force_index, old_group_name, new_group_name)
  local data = platform_data.raw(force_index)
  local group = data.groups[old_group_name]
  if group then
    group.name = new_group_name
    data.groups[old_group_name] = nil
    data.groups[new_group_name] = group
  end
end

-- Delete a group if it exists.
---@param force_index uint32
---@param group_name string
function platform_data.delete_group(force_index, group_name)
  local data = platform_data.raw(force_index)
  local group = data.groups[group_name]
  if group then
    for platform_index, _ in pairs(group.platforms) do
      data.platforms[platform_index] = nil
    end
    data.groups[group_name] = nil
  end
  -- TODO: fix orbit limits
end

-- Remove a platform from any group it is in.
---@param force_index uint32
---@param platform_index uint32
function platform_data.remove_platform(force_index, platform_index)
  local data = platform_data.raw(force_index)
  local group = data.platforms[platform_index]
  if group then
    data.platforms[platform_index] = nil
    group.platforms[platform_index] = nil
    group.platform_count = group.platform_count - 1
  end
  -- TODO: fix orbit limits
end

-- Add a platform to a specific group by name.
---@param force_index uint32
---@param group_name string
---@param platform_index uint32
---@return PlatformGroup
function platform_data.add_platform_to_group(force_index, group_name, platform_index)
  -- First remove platform from other groups.
  platform_data.remove_platform(force_index, platform_index)

  local group = platform_data.get_or_create_group(force_index, group_name)
  local platforms = platform_data.raw(force_index).platforms
  platforms[platform_index] = group
  group.platforms[platform_index] = game.forces[force_index].platforms[platform_index]
  group.platform_count = group.platform_count + 1
  -- TODO: fix orbit limits
  return group
end

-- Get the group of a platform if it has one.
---@param force_index uint32
---@param platform_index uint32
---@return PlatformGroup?
---@nodiscard
function platform_data.get_group_of_platform(force_index, platform_index)
  return platform_data.raw(force_index).platforms[platform_index]
end

return platform_data
