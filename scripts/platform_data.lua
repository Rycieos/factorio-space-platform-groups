local logistics_provider = require("scripts.logistics_provider")
local queue = require("scripts.queue")
local schedule = require("scripts.schedule")

local platform_data = {}

---@class (exact) PlatformGroup
---@field name string
---@field force uint32
---@field platforms { [uint32]: string } Mapping of platform_index to recorded space_location.
---@field platform_count uint32
---@field load_limit? uint8
---@field unload_limit? uint8
---@field space_location_queues { [string]: Queue<uint32> }

---@class (exact) PlatformData
---@field groups { [string]: PlatformGroup }
---@field platforms { [uint32]: PlatformGroup }

-- Get the PlatformData storage table for the specified Force.
---@param force_index uint32
---@return PlatformData
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

-- Add a platform to the queue of the location it is in, if not already in the queue.
---@param group PlatformGroup
---@param platform_index uint32
local function remove_platform_from_queue(group, platform_index)
  if group.platforms[platform_index] ~= "" then
    local location_queue = platform_data.get_location_queue(group, group.platforms[platform_index])
    local index = queue.find(location_queue, platform_index)
    if index > 0 then
      queue.remove(location_queue, index)
    end
    group.platforms[platform_index] = ""
    platform_data.manage_logistics_providers(group)
  end
end

-- Remove a platform from any group it is in.
---@param force_index uint32
---@param platform_index uint32
function platform_data.remove_platform(force_index, platform_index)
  local data = raw(force_index)
  local group = data.platforms[platform_index]
  if group then
    remove_platform_from_queue(group, platform_index)
    data.platforms[platform_index] = nil
    group.platforms[platform_index] = nil
    group.platform_count = group.platform_count - 1
    if group.platform_count == 0 then
      platform_data.delete_group(force_index, group.name)
    end
  end
end

-- Add a platform to the queue of the location it is in, if not already in the queue.
---@param group PlatformGroup
---@param platform LuaSpacePlatform
local function add_platform_to_queue(group, platform)
  if platform.space_location then
    local location_name = platform.space_location.name
    if location_name ~= group.platforms[platform.index] then
      group.platforms[platform.index] = location_name
      local location_queue = platform_data.get_location_queue(group, location_name)
      queue.push(location_queue, platform.index)
    end
    platform_data.manage_logistics_providers(group)
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
  group.platforms[platform_index] = ""
  group.platform_count = group.platform_count + 1

  local force = game.forces[force_index]
  if force then
    local platform = force.platforms[platform_index]
    if platform then
      platform_data.sync_schedule_to(platform)
      add_platform_to_queue(group, platform)
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

-- Get a group's location queue for a location.
---@param group PlatformGroup
---@param space_location string
function platform_data.get_location_queue(group, space_location)
  if not group.space_location_queues[space_location] then
    group.space_location_queues[space_location] = queue.new()
  end
  return group.space_location_queues[space_location]
end

-- Update logistics providers on all platforms in this group.
---@param group PlatformGroup
function platform_data.manage_logistics_providers(group)
  for platform_index, location in pairs(group.platforms) do
    if location == "" then
      logistics_provider.set_state(group.force, platform_index, true, true)
    end
  end
  for _, location_queue in pairs(group.space_location_queues) do
    for index, platform_index in queue.iter(location_queue) do
      logistics_provider.set_state(
        group.force,
        platform_index,
        not group.unload_limit or index <= group.unload_limit,
        not group.load_limit or index <= group.load_limit
      )
    end
  end
end

---@param from_platform LuaSpacePlatform
function platform_data.sync_schedule_from(from_platform)
  local group = platform_data.get_group_of_platform(from_platform.force.index, from_platform.index)
  if group then
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

  if group.platforms[platform.index] ~= "" then
    remove_platform_from_queue(group, platform.index)
  end
  if platform.space_location then
    add_platform_to_queue(group, platform)
  end

  for _, player in pairs(platform.force.players) do
    space_platform_gui.update(player.index, platform.index)
  end
end

return platform_data
