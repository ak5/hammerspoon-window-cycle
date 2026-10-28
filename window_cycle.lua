-- The Window menu sees other Spaces; hs.application:allWindows() does not.
local pending, session
local cycle = {}

local function windowMenu(app)
  local element = hs.axuielement.applicationElement(app)
  local bar = element and element:attributeValue("AXMenuBar")
  for _, menu in ipairs(bar and bar:attributeValue("AXChildren") or {}) do
    -- shortcut: English Window menus only; add localization when needed.
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

local function startSession(menu, direction)
  local focused = menu.app:focusedWindow()
  if not focused then return end
  local space, locals = hs.spaces.focusedSpace(), {}
  for _, window in ipairs(menu.app:allWindows()) do
    if window:id() ~= focused:id() and window:isStandard() and not window:isMinimized() then
      for _, windowSpace in ipairs(hs.spaces.windowSpaces(window) or {}) do
        if windowSpace == space then locals[#locals + 1] = window; break end
      end
    end
  end
  table.sort(locals, function(a, b) return direction * a:id() < direction * b:id() end)
  local entries = { { window = focused, menu = menu.windows[menu.index] } }
  for _, window in ipairs(locals) do entries[#entries + 1] = { window = window } end
  return { app = menu.app, entries = entries, index = 1, direction = direction, localOnly = true }
end

local function selectNext(direction)
  local app = hs.application.frontmostApplication()
  if not app then return end
  local menu = windowMenu(app)
  if not menu then
    session, pending = nil, nil
    hs.alert.show("Cannot find the current window in the Window menu")
    return
  end
  local focused, checked = app:focusedWindow(), menu.windows[menu.index]
  local current = session and session.entries[session.index]
  if not session or session.app:pid() ~= app:pid() or session.direction ~= direction
      or (current.menu and current.menu ~= checked)
      or (not current.menu and (not focused or current.window:id() ~= focused:id())) then
    session = startSession(menu, direction)
  end
  if not session then return end
  -- Learn menu identities as local windows are visited; titles need not be unique.
  session.entries[session.index].menu = checked
  if session.localOnly and session.index == #session.entries then
    local first, last = 1, #menu.windows
    if direction == -1 then first, last = last, first end
    for i = first, last, direction do
      local seen = false
      for _, entry in ipairs(session.entries) do
        if entry.menu == menu.windows[i] then seen = true; break end
      end
      if not seen then session.entries[#session.entries + 1] = { menu = menu.windows[i] } end
    end
    session.localOnly = false
  end
  pending = { session = session, index = session.index % #session.entries + 1 }
end

local function whenReleased()
  local selection = pending
  pending = nil
  local front = hs.application.frontmostApplication()
  if not selection or not front or front:pid() ~= selection.session.app:pid() then return end
  local entry = selection.session.entries[selection.index]
  local ok
  if entry.menu then ok = entry.menu:performAction("AXPress") else ok = entry.window:focus() end
  if ok then
    selection.session.index = selection.index
  else
    session = nil
    hs.alert.show("Window switch failed; try again")
  end
end

-- Registered hotkeys still work with Secure Input; keyboard event taps do not.
cycle.hotkeys = {
  hs.hotkey.new({ "cmd" }, "`", function() selectNext(1) end, whenReleased),
  hs.hotkey.new({ "cmd", "shift" }, "`", function() selectNext(-1) end, whenReleased),
}
-- Only observe modifiers; registered hotkeys handle keypresses even with Secure Input.
cycle.modifiers = hs.eventtap.new({ hs.eventtap.event.types.flagsChanged }, function(event)
  if not event:getFlags().cmd then session = nil end
  return false
end):start()
local function updateHotkeys()
  local app = hs.application.frontmostApplication()
  local enabled = app and windowMenu(app) ~= nil
  if pending and (not app or pending.session.app:pid() ~= app:pid()) then
    pending = nil
  end
  for _, key in ipairs(cycle.hotkeys) do
    if enabled then key:enable() else key:disable() end
  end
end
local function watchApp()
  if cycle.windowWatcher then cycle.windowWatcher:stop(); cycle.windowWatcher = nil end
  local app = hs.application.frontmostApplication()
  if app then
    cycle.windowWatcher = app:newWatcher(updateHotkeys):start({
      hs.uielement.watcher.focusedWindowChanged,
      hs.uielement.watcher.windowCreated,
    })
  end
  updateHotkeys()
end
cycle.watcher = hs.application.watcher.new(function(_, event)
  if event == hs.application.watcher.activated then watchApp() end
end):start()
watchApp()
return cycle
