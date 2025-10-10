local queue = {}

---@class Queue<T>: { [integer]: T, first: integer, last: integer }

---@return Queue
function queue.new()
  return { first = 1, last = 0 }
end

-- Push an element into the back of the queue.
---@generic T
---@param list Queue<T>
---@param value T
function queue.push(list, value)
  local last = list.last + 1
  list.last = last
  list[last] = value
end

-- Retrieve an element from the front of the queue.
---@generic T
---@param list Queue<T>
---@return T?
function queue.pop(list)
  local first = list.first
  if first > list.last then
    return
  end
  local value = list[first]
  list[first] = nil
  list.first = first + 1
  return value
end

-- Delete an element from the queue at index.
-- Maybe not a true queue then, but we need a way to remove invalid items.
---@generic T
---@param list Queue<T>
---@param index integer indexed by 1.
---@return T?
function queue.remove(list, index)
  list.last = list.last - 1
  return table.remove(list, list.first + index - 1)
end

-- Get the number of elements in the queue.
---@generic T
---@param list Queue<T>
---@return integer
function queue.size(list)
  return list.last - list.first + 1
end

-- Get an element from the queue at index.
---@generic T
---@param list Queue<T>
---@param index integer indexed by 1.
---@return T?
function queue.get(list, index)
  return list[list.first + index - 1]
end

-- Resolve an optional virtual last index capped to the actual last.
---@generic T
---@param list Queue<T>
---@param last? integer
---@return integer
local function resolve_last(list, last)
  if last then
    return math.min(list.first + last - 1, list.last)
  end
  return list.last
end

-- Get a slice of the queue from first to last index.
---@generic T
---@param list Queue<T>
---@param first integer indexed by 1.
---@param last? integer indexed by 1, inclusive, default size of queue.
---@return T[]
function queue.slice(list, first, last)
  local slice = {}
  for index = list.first + first - 1, resolve_last(list, last) do
    table.insert(slice, list[index])
  end
  return slice
end

-- Iterate over a queue's elements from first to last index.
---@generic T
---@param list Queue<T>
---@param first? integer indexed by 1, default 1.
---@param last? integer indexed by 1, inclusive, default size of queue.
---@return fun(): integer, T
function queue.iter(list, first, last)
  local i = list.first + (first or 1) - 2
  last = resolve_last(list, last)
  return function()
    if i < last then
      i = i + 1
      return i, list[i]
    end
  end
end

-- Find the index of an item in the queue.
---@generic T
---@param list Queue<T>
---@param item T
---@return integer index of the first matching item, if it exists. If not, return `0`.
function queue.find(list, item)
  for index, element in queue.iter(list) do
    if element == item then
      return index
    end
  end
  return 0
end

return queue
