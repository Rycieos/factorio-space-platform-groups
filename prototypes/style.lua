local const = require("const")

local styles = data.raw["gui-style"]["default"]

styles[const.vertical_container_frame] = {
  type = "frame_style",
  parent = "inset_frame_container_frame",
  vertical_flow_style = {
    type = "vertical_flow_style",
    parent = "inset_frame_container_vertical_flow",
    vertical_spacing = 0,
  },
}

styles[const.scroll_pane] = {
  type = "scroll_pane_style",
  parent = "list_box_scroll_pane",
  horizontally_stretchable = "stretch_and_expand",
  vertically_stretchable = "stretch_and_expand",
  vertical_flow_style = {
    type = "vertical_flow_style",
    vertical_spacing = 0,
  },
}
