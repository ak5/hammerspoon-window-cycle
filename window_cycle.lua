-- The Window menu sees other Spaces; hs.application:allWindows() does not.
local supported = { ["com.google.Chrome"] = true, ["com.mitchellh.ghostty"] = true }
local pending
local cycle = {}

local function windowMenu(app)
  local bar = hs.axuielement.applicationElement(app):attributeValue("AXMenuBar")
  for _, menu in ipairs(bar and bar:attributeValue("AXChildren") or {}) do
    -- shortcut: English menus in Chrome/Ghostty only; extend when another app is needed.
    if menu:attributeValue("AXTitle") == "Window" then
      local submenu = (menu:attributeValue("AXChildren") or {})[1]
      local rows = submenu and submenu:attributeValue("AXChildren") or {}
      local windows, current = {}, nil
      for _, row in ipairs(rows) do
        if (row:attributeValue("AXTitle") or "") == "" then
          windows, current = {}, nil
        else
          windows[#windows + 1] = row
          if row:attributeValue("AXMenuItemMarkChar") == "✓" then current = #windows end
        end
      end
      if current then return { app = app, windows = windows, index = current } end
    end
  end
end

local function selectNext(direction)
  local app = hs.application.frontmostApplication()
  if not app or not supported[app:bundleID()] then return end
  if not pending or pending.app:pid() ~= app:pid() then pending = windowMenu(app) end
  if not pending then
    hs.alert.show("Cannot find the current window in the Window menu")
    return
  end
  pending.index = (pending.index - 1 + direction) % #pending.windows + 1
end

local function whenReleased()
  local selection = pending
  pending = nil
  local front = hs.application.frontmostApplication()
  if not selection or not front or front:pid() ~= selection.app:pid() then return end
  local ok = selection.windows[selection.index]:performAction("AXPress")
  if not ok then hs.alert.show("Window switch failed; try again") end
end

-- Registered hotkeys still work with Secure Input; keyboard event taps do not.
cycle.hotkeys = {
  hs.hotkey.new({ "cmd" }, "`", function() selectNext(1) end, whenReleased),
  hs.hotkey.new({ "cmd", "shift" }, "`", function() selectNext(-1) end, whenReleased),
}
local function updateHotkeys()
  local app = hs.application.frontmostApplication()
  local enabled = app and supported[app:bundleID()]
  if pending and (not app or pending.app:pid() ~= app:pid()) then
    pending = nil
  end
  for _, key in ipairs(cycle.hotkeys) do
    if enabled then key:enable() else key:disable() end
  end
end
cycle.watcher = hs.application.watcher.new(function(_, event)
  if event == hs.application.watcher.activated then updateHotkeys() end
end):start()
updateHotkeys()
return cycle
