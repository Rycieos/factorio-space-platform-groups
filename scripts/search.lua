local to_lower_func = helpers.compare_versions(helpers.game_version, "2.0.67") >= 0 and helpers.multilingual_to_lower
  or string.lower

local search = {}

-- Hide members and filters based on matching the query to the name of the
-- buttons.
---@param guis Guis
function search.update_search_results(guis)
  local query = guis.search_box.text
  query = to_lower_func(query)

  for _, member in pairs(guis.groups_list.children) do
    if query == "" then
      member.visible = true
    elseif member.tags.ignored_by_search then
      member.visible = false
    else
      member.visible = string.find(to_lower_func(member.caption --[[@as string]]), query, 1, true) ~= nil
    end
  end
end

return search
