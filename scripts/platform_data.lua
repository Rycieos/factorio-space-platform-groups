local logistics_provider = require("scripts.logistics_provider")
local schedule = require("scripts.schedule")

local platform_data = {}

---@class PlatformData
---@field group PlatformGroup
---@field platform_index uint32
---@field location string?
---@field ticks_in_station uint64
---@field location_queue_index? uint32
---@field location_queue_size? uint32

---@class (exact) PlatformGroup
---@field name string
---@field force uint32
---@field platforms { [uint32]: PlatformData }
---@field platform_count uint32
---@field load_limit? uint8
---@field unload_limit? uint8

---@class (exact) PlatformGroupData
---@field groups { [string]: PlatformGroup }
---@field platforms { [uint32]: PlatformGroup }

-- Get the PlatformGroupData storage table for the specified Force.
---@param force_index uint32
---@return PlatformGroupData
---@nodiscard
local function raw(force_index)
  if not storage.force_data[force_index] then
    storage.force_data[force_index] = {
      groups = {},
      platforms = {},
    }
  end
  return storage.force_data[force_index]
end

-- Get all the groups that a force owns, sorted by name.
---@param force_index uint32
---@return PlatformGroup[]
function platform_data.get_groups(force_index)
  local data = raw(force_index)
  local groups = {}
  for _, group in pairs(data.groups) do
    table.insert(groups, group)
  end
  table.sort(groups, function(a, b)
    return a.name < b.name
  end)
  return groups
end

-- Get the PlatformGroup by the name, creating it if it does not exist.
---@param force_index uint32
---@param group_name string
---@return PlatformGroup
---@nodiscard
local function get_or_create_group(force_index, group_name)
  local data = raw(force_index)
  if not data.groups[group_name] then
    data.groups[group_name] = {
      name = group_name,
      force = force_index,
      platforms = {},
      platform_count = 0,
      space_location_queues = {},
    }
  end
  return data.groups[group_name]
end

-- Rename the group from old_group_name to new_group_name.
---@param force_index uint32
---@param old_group_name string
---@param new_group_name string
function platform_data.rename_group(force_index, old_group_name, new_group_name)
  local data = raw(force_index)
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
  local data = raw(force_index)
  local group = data.groups[group_name]
  if group then
    for platform_index, _ in pairs(group.platforms) do
      data.platforms[platform_index] = nil
      logistics_provider.set_state(group.force, platform_index, true, true)
    end
    data.groups[group_name] = nil
  end
end

-- Remove a platform from any group it is in.
---@param force_index uint32
---@param platform_index uint32
function platform_data.remove_platform(force_index, platform_index)
  local data = raw(force_index)
  local group = data.platforms[platform_index]
  if group then
    if group.platforms[platform_index].location ~= nil then
      group.platforms[platform_index].location = nil
      platform_data.manage_logistics_providers(group)
    end
    data.platforms[platform_index] = nil
    group.platforms[platform_index] = nil
    group.platform_count = group.platform_count - 1
    if group.platform_count == 0 then
      platform_data.delete_group(force_index, group.name)
    end
  end
end

-- Add a platform to a specific group by name.
---@param force_index uint32
---@param group_name string
---@param platform_index uint32
---@return PlatformGroup
function platform_data.add_platform_to_group(force_index, group_name, platform_index)
  -- First remove platform from other groups.
  platform_data.remove_platform(force_index, platform_index)

  local group = get_or_create_group(force_index, group_name)
  local platforms = raw(force_index).platforms
  platforms[platform_index] = group
  group.platforms[platform_index] = {
    group = group,
    platform_index = platform_index,
    ticks_in_station = 0,
  }
  group.platform_count = group.platform_count + 1

  local force = game.forces[force_index]
  if force then
    local platform = force.platforms[platform_index]
    if platform then
      platform_data.sync_schedule_to(platform)
      if platform.space_location then
        group.platforms[platform_index].location = platform.space_location.name
        platform_data.manage_logistics_providers(group)
      end
    end
  end
  return group
end

-- Get the group of a platform if it has one.
---@param force_index uint32
---@param platform_index uint32
---@return PlatformGroup?
---@nodiscard
function platform_data.get_group_of_platform(force_index, platform_index)
  return raw(force_index).platforms[platform_index]
end

-- Update logistics providers on all platforms in this group.
---@param group PlatformGroup
function platform_data.manage_logistics_providers(group)
  ---@type table<string, PlatformData[]>
  local location_queues = {}
  for platform_index, data in pairs(group.platforms) do
    if data.location == nil then
      data.location_queue_index = nil
      data.location_queue_size = nil
      logistics_provider.set_state(group.force, platform_index, true, true)
    else
      local platform = ((game.forces[group.force] or {}).platforms or {})[platform_index]
      if platform then
        data.ticks_in_station = platform.get_schedule().ticks_in_station
      end
      if not location_queues[data.location] then
        location_queues[data.location] = {}
      end
      table.insert(location_queues[data.location], data)
    end
  end
  for _, location_queue in pairs(location_queues) do
    table.sort(location_queue, function(a, b)
      return a.ticks_in_station > b.ticks_in_station
    end)
    for index, platform in ipairs(location_queue) do
      platform.location_queue_index = index
      platform.location_queue_size = #location_queue
      logistics_provider.set_state(
        group.force,
        platform.platform_index,
        not group.unload_limit or index <= group.unload_limit,
        not group.load_limit or index <= group.load_limit
      )
    end
  end
end

---@param group PlatformGroup
---@param platform_index uint32
---@param type ("load_limit")|("unload_limit")
---@return string
function platform_data.get_logistic_status(group, platform_index, type)
  if group[type] then
    local platform = group.platforms[platform_index]
    if platform.location == nil then
      return "blue"
    end
    if platform.location_queue_size <= group[type] then
      return "working"
    elseif platform.location_queue_index <= group[type] then
      return "yellow"
    else
      return "not_working"
    end
  end
  return "inactive"
end

---@param from_platform LuaSpacePlatform
function platform_data.sync_schedule_from(from_platform)
  local group = platform_data.get_group_of_platform(from_platform.force.index, from_platform.index)
  if group and group.platform_count > 1 then
    local to_platforms = {}
    for platform_index, _ in pairs(group.platforms) do
      table.insert(to_platforms, from_platform.force.platforms[platform_index])
    end
    schedule.sync_schedules(from_platform, to_platforms)
  end
end

---@param to_platform LuaSpacePlatform
function platform_data.sync_schedule_to(to_platform)
  local group = platform_data.get_group_of_platform(to_platform.force.index, to_platform.index)
  if group and group.platform_count > 1 then
    -- Find some other platform that isn't the one we are copying to.
    ---@type LuaSpacePlatform
    local from_platform
    for platform_index, _ in pairs(group.platforms) do
      if platform_index ~= to_platform.index then
        from_platform = to_platform.force.platforms[platform_index]
        break
      end
    end
    schedule.sync_schedules(from_platform, { to_platform })
  end
end

-- Handle a space platform leaving or entering a space location.
---@param event EventData.on_space_platform_changed_state
function platform_data.on_space_platform_changed_state(event)
  local platform = event.platform
  local group = platform_data.get_group_of_platform(platform.force.index, platform.index)
  if not group then
    return
  end

  local new_state = platform.state
  local states = defines.space_platform_state
  if
    new_state == states.waiting_for_starter_pack
    or new_state == states.starter_pack_requested
    or new_state == states.starter_pack_on_the_way
  then
    return
  end

  -- While in state waiting_for_departure, a platform can still automatically drop requests.

  -- We do not want to limit a paused platform. Not only does the game not track
  -- how long they are at a planet, but it is unintuitive that a paused platform
  -- would take up limit slots.
  local new_location = (platform.space_location and not platform.paused) and platform.space_location.name or nil
  if group.platforms[platform.index].location ~= new_location then
    group.platforms[platform.index].location = new_location
    platform_data.manage_logistics_providers(group)

    for _, player in pairs(platform.force.players) do
      space_platform_gui.update(player.index, platform.index)
    end
  end
end

-- Handle a space platform being deleted.
---@param event EventData.on_pre_surface_deleted
function platform_data.on_pre_surface_deleted(event)
  local surface = game.surfaces[event.surface_index]
  if surface and surface.platform then
    platform_data.remove_platform(surface.platform.force.index, surface.platform.index)
  end
end

return platform_data
