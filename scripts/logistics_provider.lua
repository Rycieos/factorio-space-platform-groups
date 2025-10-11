local logistics_provider = {}

-- Set enabled/disabled on logistic points on a platform hub.
-- Idempotent, to prevent drift.
---@param force_index uint32
---@param platform_index uint32
---@param provider_enabled boolean
---@param requester_enabled boolean
function logistics_provider.set_state(force_index, platform_index, provider_enabled, requester_enabled)
  local force = game.forces[force_index]
  if not force then
    return
  end
  local platform = force.platforms[platform_index]
  if not platform then
    return
  end
  local hub = platform.hub
  if not hub then
    return
  end
  local provider = hub.get_logistic_point(defines.logistic_member_index.space_platform_hub_provider)
  if provider then
    provider.enabled = provider_enabled
  end
  local requester = hub.get_logistic_point(defines.logistic_member_index.space_platform_hub_requester)
  if requester then
    requester.enabled = requester_enabled
  end
end

return logistics_provider
