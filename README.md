[![Mod downloads](https://img.shields.io/badge/dynamic/json?color=orange&label=Factorio&query=downloads_count&suffix=%20downloads&url=https%3A%2F%2Fmods.factorio.com%2Fapi%2Fmods%2Fspace_platform_groups)](https://mods.factorio.com/mod/space_platform_groups)

# Space Platform Groups

A mod for [Factorio](https://factorio.com/) that adds space platform groups,
just like train groups. Similarly to how train stations can limit number of
trains, groups can limit number of platforms that load (request) and unload
(provide) at a planet.

Features include:

* Adding space platforms to a group.
* Syncing schedules between all platforms in a group.
* Limiting the number of platfoms in a group that can load (request) at a
  planet at one time, per group.
* A separate limit for unloading (providing).
* Platforms will "queue" at a planet, where the first N platforms to arrive
  will be allowed to load/unload, where N equals the set limit. As platforms
  leave the planet, platforms behind in the queue will be unlimited.

![Thumbnail](https://raw.githubusercontent.com/Rycieos/factorio-space-platform-groups/main/thumbnail.png)

### Experimental

This mod has not been extensively tested, so please report any issues.

#### Known issues:

* Until [this bug](https://forums.factorio.com/viewtopic.php?t=131263) is
  fixed, limiting unloading does nothing.

### Uninstallation

The group membership data is stored locally to this mod, and so obviously is
lost when the mod is removed from a save. This is completely safe to do, with
the exception of limits. If any groups have limits set, you will need to do one
of two things:

1. Disable all limits on groups before removing the mod.
2. If the mod was already removed from the save, this is the only option. Run
   this command in the console:

```lua
/c for _, force in pairs(game.forces) do
  for _, platform in pairs(force.platforms) do
    local hub = platform.hub
    if hub then
      local provider = hub.get_logistic_point(defines.logistic_member_index.space_platform_hub_provider)
      if provider then
        provider.enabled = true
      end
      local requester = hub.get_logistic_point(defines.logistic_member_index.space_platform_hub_requester)
      if requester then
        requester.enabled = true
      end
    end
  end
end
```

### Getting help

For bug reports or specific feature requests, please [open a new
issue](https://github.com/Rycieos/factorio-space-platform-groups/issues/new/choose).
Please check if your issue has already been reported before opening a new one.

For questions or anything else, please [open a new
discussion](https://github.com/Rycieos/factorio-space-platform-groups/discussions/new/choose).
