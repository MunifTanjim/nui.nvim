local utils = require("nui.utils")

local notification_ctl = {
  active_notifications = {
    topright = {},
    topleft = {},
    botright = {},
    botleft = {},
  },
}

local function get_window_height(popup)
  if popup:has_border() then
    return popup.border.win_config.height
  else
    return popup.win_config.height
  end
end

local function is_position_top(position_text)
  return position_text:sub(1, 3) == "top"
end

local function get_new_position(position_text, popup, height_diff, demote)
  local curr = popup.win_config
  local new_row

  -- FIXME: Why is `popup.height` not already correct when we have a "native" border? 0-indexing?
  if utils._.is_border_builtin(popup.winid) then
    height_diff = height_diff + 2
  end

  -- Move up/down depending if the notification is positioned on top or bottom,
  -- then in the opposite direction again if demoting
  if is_position_top(position_text) then
    new_row = curr.row + (demote and -height_diff or height_diff)
  else
    new_row = curr.row + (demote and height_diff or -height_diff)
  end

  return {
    col = curr.col,
    row = new_row,
    height = curr.height,
    width = curr.width,
  }
end

local function check_moved_window_out_of_bounds(position_text, new_config)
  -- Check if the edge of the window is beyond the bounds of the editor
  --
  -- The "origin" for a window is its top-left corner
  if is_position_top(position_text) then
    -- Windows are moved down, 'row' is at the bottom of the window
    return new_config.row + new_config.height >= utils.get_editor_size().height
  else
    -- Windows are moved up
    return new_config.row <= 1
  end
end

notification_ctl.move_notification_windows = function(new_notification)
  local new_popup = new_notification
  local last_popup = new_popup
  local position_text = new_notification.notification_options.position_text

  for _, curr_popup in ipairs(notification_ctl.active_notifications[position_text]) do
    local new_config = get_new_position(position_text, curr_popup, get_window_height(last_popup))

    if check_moved_window_out_of_bounds(position_text, new_config) then
      notification_ctl.remove_active_notification(position_text, curr_popup)
    else
      new_config.row = new_config.row
      curr_popup:set_position(new_config)
    end

    last_popup = curr_popup
  end
end

notification_ctl.add_active_notification = function(notification)
  table.insert(notification_ctl.active_notifications[notification.notification_options.position_text], 1, notification)
end

-- Don't want to change our list while iterating over it, schedule this to happen
-- at some point later (order-preserving)
notification_ctl.remove_active_notification = vim.schedule_wrap(function(position_text, notification)
  local idx = 0
  local popup = notification

  if not popup.winid then
    return
  end

  for i, p in ipairs(notification_ctl.active_notifications[position_text]) do
    if p.winid == popup.winid then
      idx = i
      break
    end
  end

  popup:unmount()

  table.remove(notification_ctl.active_notifications[position_text], idx)
end)

return notification_ctl
