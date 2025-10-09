local util = {}

-- Find the index of an element in the table.
---@param table table
---@param element string
---@return uint32
function util.find(table, element)
  for index, value in pairs(table) do
    if value == element then
      return index
    end
  end
  return 0
end

return util
