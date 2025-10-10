local const = require("const")

local platform_data = {}

---@class (exact) PlatformGroup
---@field name string
---@field platforms { [uint32]: LuaSpacePlatform }
---@field platform_count uint32
---@field load_limit? uint8
---@field unload_limit? uint8

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
      platforms = {},
      platform_count = 0,
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
    end
    data.groups[group_name] = nil
  end
  -- TODO: fix orbit limits
end

-- Remove a platform from any group it is in.
---@param force_index uint32
---@param platform_index uint32
function platform_data.remove_platform(force_index, platform_index)
  local data = raw(force_index)
  local group = data.platforms[platform_index]
  if group then
    data.platforms[platform_index] = nil
    group.platforms[platform_index] = nil
    group.platform_count = group.platform_count - 1
    if group.platform_count == 0 then
      platform_data.delete_group(force_index, group.name)
    end
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

  local group = get_or_create_group(force_index, group_name)
  local platforms = raw(force_index).platforms
  platforms[platform_index] = group
  group.platforms[platform_index] = game.forces[force_index].platforms[platform_index]
  group.platform_count = group.platform_count + 1

  local force = game.forces[force_index]
  if force then
    local platform = force.platforms[platform_index]
    if platform then
      platform_data.sync_schedule_to(platform)
    end
  end

  -- TODO: fix orbit limits
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

-- Do our best to copy schedules.
-- Any temporary stop in the source is simply skipped.
-- Any temporary stop in the dest is also skipped, in the sense that it is not
-- overwritten, and we act like it isn't there, targeting the next stop for
-- overwritting.
-- Reordering is quite brittle. Train groups have the luxury of getting events
-- popped for every little change, and can catch a reorder. Without that, we
-- just have to guess based on destination.
-- Sure would be nice if Wube would let the group functionality work for platforms.
---@param from_platform LuaSpacePlatform
---@param to_platforms LuaSpacePlatform[]
function platform_data.sync_schedules(from_platform, to_platforms)
  local from_schedule = from_platform.get_schedule()
  local from_record_count = from_schedule.get_record_count()

  for _, to_platform in pairs(to_platforms) do
    if from_platform.index ~= to_platform.index then
      local to_schedule = to_platform.get_schedule()
      local stopped = to_platform.paused
      local active_index = to_schedule.current
      local active_record = to_schedule.get_record({ schedule_index = active_index }) or {}
      local active_destination = not active_record.temporary and active_record.station or nil
      local best_ahead_index, best_behind_index

      local to_index = 1
      for from_index = 1, from_record_count do
        -- Get the schedule without any temporary stops.
        local from_record = from_schedule.get_record({ schedule_index = from_index })
        if from_record and not from_record.temporary then
          local to_record = to_schedule.get_record({ schedule_index = to_index })
          while to_record and to_record.temporary do
            to_index = to_index + 1
            to_record = to_schedule.get_record({ schedule_index = to_index })
          end
          to_schedule.remove_record({ schedule_index = to_index })
          to_schedule.copy_record(from_schedule, from_index, to_index)

          if active_destination and from_record.station == active_destination then
            if to_index < active_index then
              best_ahead_index = to_index
            elseif not best_behind_index then
              best_behind_index = to_index
            end
          end

          to_index = to_index + 1
        end
      end
      -- If there are still records in the dest, remove them.
      -- Need to do it in reverse because removing the first would shift the
      -- others down.
      for index = to_schedule.get_record_count(), to_index, -1 do
        to_schedule.remove_record({ schedule_index = index })
      end
      to_schedule.set_interrupts(from_schedule.get_interrupts())

      -- Recover the previous active record (best guess).
      if active_destination then
        local best_index = active_index
        if best_ahead_index and best_behind_index then
          best_index = (active_index - best_ahead_index < best_behind_index - active_index) and best_ahead_index
            or best_behind_index
        elseif best_ahead_index then
          best_index = best_ahead_index
        elseif best_behind_index then
          best_index = best_behind_index
        end
        to_schedule.go_to_station(best_index)
        to_schedule.set_stopped(stopped)
      end
    end
  end
end

---@param from_platform LuaSpacePlatform
function platform_data.sync_schedule_from(from_platform)
  local group = platform_data.get_group_of_platform(from_platform.force.index, from_platform.index)
  if group then
    platform_data.sync_schedules(from_platform, group.platforms)
  end
end

---@param to_platform LuaSpacePlatform
function platform_data.sync_schedule_to(to_platform)
  local group = platform_data.get_group_of_platform(to_platform.force.index, to_platform.index)
  if group and group.platform_count > 1 then
    -- Find some other platform that isn't the one we are copying to.
    ---@type LuaSpacePlatform
    local from_platform
    for _, platform in pairs(group.platforms) do
      if platform.index ~= to_platform.index then
        from_platform = platform
        break
      end
    end
    platform_data.sync_schedules(from_platform, { to_platform })
  end
end

return platform_data
