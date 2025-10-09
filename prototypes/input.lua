local const = require("const")

data:extend({
  {
    type = "custom-input",
    name = const.confirm_gui_id,
    key_sequence = "",
    linked_game_control = "confirm-gui",
  },
  {
    type = "custom-input",
    name = const.focus_search_id,
    key_sequence = "",
    linked_game_control = "focus-search",
  },
})
