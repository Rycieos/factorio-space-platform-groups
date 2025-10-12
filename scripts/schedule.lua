require("util")

local schedule = {}

-- Get the index of the current record as if no temporary records existed.
---@param schedule LuaSchedule
---@return uint32
local function get_virtual_current_index(schedule)
  local offset = 0
  local current_index = schedule.current
  for i = 1, current_index - 1 do
    local record = schedule.get_record({ schedule_index = i })
    if record and record.temporary then
      offset = offset + 1
    end
  end
  return current_index - offset
end

-- Get the best index from from_schedule that matches the current index in
-- to_schedule.
--
-- Here is our guessing order:
-- 1. If a record exists in from_schedule equal to the active record, use the
--    one closest to the active index.
-- 2. If a record exists in from_schedule with the same station as the active
--    record, use the one closest to the active index.
--
-- "Closest" is defined by ignoring any temporary records.
---@param from_schedule LuaSchedule
---@param to_schedule LuaSchedule
---@return uint32?
local function get_best_match_for_current(from_schedule, to_schedule)
  local from_record_count = from_schedule.get_record_count() --[[@as uint32]]
  local active_record = to_schedule.get_record({ schedule_index = to_schedule.current })

  if not active_record or active_record.temporary then
    return
  end

  local virtual_active_index = get_virtual_current_index(to_schedule)

  ---@type uint32?
  local best_index
  local active_destination = active_record.station

  ---@type uint32?, uint32?, uint32?, uint32?
  local best_ahead_index, best_behind_index, best_virtual_ahead_index, best_virtual_behind_index
  local from_index_offset = 0
  -- Start at active_index and search both directions.
  for from_index = math.min(virtual_active_index - 1, from_record_count), 1, -1 do
    local from_record = from_schedule.get_record({ schedule_index = from_index })
    if from_record then
      if from_record.temporary then
        from_index_offset = from_index_offset + 1
      else
        if table.compare(from_record, active_record) then
          best_ahead_index, best_virtual_ahead_index = from_index, from_index + from_index_offset
          break
        end
        if active_destination and not best_ahead_name_index and from_record.station == active_destination then
          best_ahead_name_index, best_virtual_ahead_name_index = from_index, from_index + from_index_offset
        end
      end
    end
  end

  ---@type uint32?, uint32?, uint32?, uint32?
  local best_ahead_name_index, best_behind_name_index, best_virtual_ahead_name_index, best_virtual_behind_name_index
  from_index_offset = 0
  for from_index = virtual_active_index, from_record_count do
    local from_record = from_schedule.get_record({ schedule_index = from_index })
    if from_record then
      if from_record.temporary then
        from_index_offset = from_index_offset + 1
      else
        if table.compare(from_record, active_record) then
          best_behind_index, best_virtual_behind_index = from_index, from_index - from_index_offset
          break
        end
        if active_destination and not best_behind_name_index and from_record.station == active_destination then
          best_behind_name_index, best_virtual_behind_name_index = from_index, from_index - from_index_offset
        end
      end
    end
  end

  if best_ahead_index and best_behind_index then
    best_index = (virtual_active_index - best_virtual_ahead_index < best_virtual_behind_index - virtual_active_index)
        and best_ahead_index
      or best_behind_index
  else
    best_index = best_ahead_index or best_behind_index
  end

  if not best_index then
    if best_ahead_name_index and best_behind_name_index then
      best_index = (
        virtual_active_index - best_virtual_ahead_name_index < best_virtual_behind_name_index - virtual_active_index
      )
          and best_ahead_name_index
        or best_behind_name_index
    else
      best_index = best_ahead_name_index or best_behind_name_index
    end
  end

  return best_index
end

-- Do our best to copy schedules.
-- Any temporary stop in the source is simply skipped.
-- Any temporary stop in the dest is also skipped, in the sense that it is not
-- overwritten, and we act like it isn't there, targeting the next stop for
-- overwritting.
-- Reordering is quite brittle, and while the schedule is copied exactly, the
-- current destination of each platform might be lost. Train groups have the
-- luxury of getting events popped for every little change, and can catch a
-- reorder. Without that, we just have to guess based on destination.
--
-- Sure would be nice if Wube would let the group functionality work for platforms.
---@param from_platform LuaSpacePlatform
---@param to_platforms LuaSpacePlatform[]
function schedule.sync_schedules(from_platform, to_platforms)
  local from_schedule = from_platform.get_schedule()
  local from_record_count = from_schedule.get_record_count() --[[@as uint32]]

  for _, to_platform in pairs(to_platforms) do
    if from_platform.index ~= to_platform.index then
      local to_schedule = to_platform.get_schedule()

      -- Find the record to set as current.
      local best_index = get_best_match_for_current(from_schedule, to_schedule)
      if best_index then
        -- The current record might be deleted before the record we will set as
        -- current is added. This makes the platform start moving toward the
        -- next record for a very short time. To fix this, simply move the
        -- current record back to where we will be putting the new current
        -- record. This can change record order if there are temporary stops,
        -- but only if also the active record changed position. And either
        -- result could be more correct; all bets are off when reordering.
        to_schedule.drag_record(to_schedule.current, best_index)
      end

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
          to_schedule.copy_record(from_schedule, from_index, to_index)
          if best_index and from_index == best_index then
            -- set the best guess record as active. If we manually set the
            -- pasted record as active, it causes a state change event, even
            -- though the platform does not go anywhere. If instead we drop down
            -- to it by removing the active record, it seems no event is fired.
            to_schedule.drag_record(to_index + 1, to_index)
            to_schedule.remove_record({ schedule_index = to_index })
          else
            -- If there is no guess, the following line removing the active record
            -- will make the next record the active one. Which will cascade to the
            -- end, making the first record active. I think that is what train
            -- schedules do, so it's not so bad.
            to_schedule.remove_record({ schedule_index = to_index + 1 })
          end

          to_index = to_index + 1
        end
      end
      -- If there are still records in the dest, remove them, if they are not
      -- temporary. Need to do it in reverse because removing the first would
      -- shift the others down.
      for index = to_schedule.get_record_count(), to_index, -1 do
        local to_record = to_schedule.get_record({ schedule_index = index })
        if to_record and not to_record.temporary then
          to_schedule.remove_record({ schedule_index = index })
        end
      end
      to_schedule.set_interrupts(from_schedule.get_interrupts())
    end
  end
end

return schedule
