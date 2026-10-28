-- The Window menu sees other Spaces; hs.application:allWindows() does not.
local overlay = require("window_cycle_overlay")
local session
local knownByPID = {}
local cycle = { trace = {} }

-- Opt-in, bounded, in-memory diagnostics: no titles, profile names, or typed text.
local function trace(event, data)
  if not cycle.tracing then return end
  data = data or {}
  data.event, data.time = event, hs.timer.secondsSinceEpoch()
  cycle.trace[#cycle.trace + 1] = data
  if #cycle.trace > 200 then table.remove(cycle.trace, 1) end
end

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

local function matchesTitle(windowTitle, menuTitle)
  return type(windowTitle) == "string" and menuTitle ~= "" and windowTitle:sub(1, #menuTitle) == menuTitle
end

local function remember(menu)
  local counts = {}
  for _, row in ipairs(menu.windows) do
    local title = row:attributeValue("AXTitle") or ""
    counts[title] = (counts[title] or 0) + 1
  end
  local focused = menu.app:focusedWindow()
  local checked = menu.windows[menu.index]
  local checkedTitle = checked:attributeValue("AXTitle") or ""
  local retained = {}
  for _, entry in ipairs(knownByPID[menu.app:pid()] or {}) do
    -- Menu rows can be reused for different windows; never trust row identity alone.
    if counts[entry.menuTitle] == 1 and entry.menu:attributeValue("AXTitle") == entry.menuTitle
      and entry.window:id() and matchesTitle(entry.window:title(), entry.menuTitle)
      and (not focused or entry.window:id() ~= focused:id()) then
      retained[#retained + 1] = entry
    end
  end
  if focused and counts[checkedTitle] == 1 and matchesTitle(focused:title(), checkedTitle) then
    retained[#retained + 1] = { menu = checked, menuTitle = checkedTitle, window = focused }
  end
  knownByPID[menu.app:pid()] = retained
end

local function startSession(menu, direction)
  remember(menu)
  local space, localWindows = hs.spaces.focusedSpace(), {}
  for _, window in ipairs(menu.app:allWindows()) do
    if window:isStandard() and not window:isMinimized() then
      for _, windowSpace in ipairs(hs.spaces.windowSpaces(window) or {}) do
        if windowSpace == space then localWindows[window:id()] = window; break end
      end
    end
  end
  local matches, uses = {}, {}
  for i, row in ipairs(menu.windows) do
    local title = row:attributeValue("AXTitle") or ""
    for id, window in pairs(localWindows) do
      local windowTitle = window:title() or ""
      -- Window titles can include an app/profile suffix absent from the menu.
      if matchesTitle(windowTitle, title) then
        matches[i] = matches[i] or {}
        matches[i][#matches[i] + 1] = id
        uses[id] = (uses[id] or 0) + 1
      end
    end
  end
  local here, elsewhere, entries = {}, {}, {}
  for i, row in ipairs(menu.windows) do
    local entry = { menu = row, title = row:attributeValue("AXTitle") or "" }
    for _, observed in ipairs(knownByPID[menu.app:pid()] or {}) do
      if observed.menu == row then
        entry.windowTitle = observed.window:title()
        if localWindows[observed.window:id()] then entry.windowID = observed.window:id() end
        break
      end
    end
    -- shortcut: ambiguous titles retain menu order; use stable app-provided IDs if available.
    if not entry.windowID and matches[i] and #matches[i] == 1 and uses[matches[i][1]] == 1 then
      entry.windowID = matches[i][1]
    end
    if i == menu.index then
      local focused = menu.app:focusedWindow()
      if focused and matchesTitle(focused:title(), entry.title) then
        entry.windowID, entry.windowTitle = focused:id(), focused:title()
      end
    end
    if entry.windowID and localWindows[entry.windowID] then entry.windowTitle = localWindows[entry.windowID]:title() end
    if i == menu.index then entries[1] = entry
    elseif entry.windowID then here[#here + 1] = entry
    else elsewhere[#elsewhere + 1] = entry end
  end
  table.sort(here, function(a, b) return direction * a.windowID < direction * b.windowID end)
  for _, entry in ipairs(here) do entries[#entries + 1] = entry end
  for i = 1, #elsewhere do
    entries[#entries + 1] = elsewhere[direction == 1 and i or #elsewhere - i + 1]
  end
  return { app = menu.app, entries = entries, index = 1, direction = direction, originID = entries[1].windowID }
end

local function dismiss(reason)
  if session then trace("dismiss", { reason = type(reason) == "string" and reason or "escape" }) end
  local selection = session
  session = nil
  overlay.hide()
  for _, key in ipairs(cycle.cancelKeys) do key:disable() end
  return selection
end

local function selectNext(direction)
  trace("press", { direction = direction, active = session ~= nil })
  local app = hs.application.frontmostApplication()
  if not app then return end
  if session and session.app:pid() ~= app:pid() then dismiss("app-changed") end
  if not session then
    local menu = windowMenu(app)
    if not menu then trace("press-no-menu"); return end
    session = startSession(menu, direction)
  end
  session.index = (session.index - 1 + direction * session.direction) % #session.entries + 1
  overlay.show(session)
  trace("preview", { index = session.index, count = #session.entries })
  for _, key in ipairs(cycle.cancelKeys) do key:enable() end
end

local function finish()
  local selection = dismiss("command-released")
  if not selection then return end
  hs.timer.doAfter(0, function()
    local front = hs.application.frontmostApplication()
    if not front or front:pid() ~= selection.app:pid() then trace("commit-app-changed"); return end
    local entry = selection.entries[selection.index]
    local menu = windowMenu(front)
    local target, matches = nil, 0
    for _, row in ipairs(menu and menu.windows or {}) do
      if row:attributeValue("AXTitle") == entry.title then
        matches = matches + 1
        target = row
      end
    end
    -- A fresh menu resolves rows that were rebuilt while the preview was open.
    if matches ~= 1 then
      target = nil
      for _, row in ipairs(menu and menu.windows or {}) do
        if row == entry.menu and row:attributeValue("AXTitle") == entry.title then target = row; break end
      end
    end
    local ok, err
    if target then ok, err = target:performAction("AXPress") end
    trace("commit", { target = target ~= nil, success = ok ~= nil and ok ~= false, actionError = err ~= nil })
    if not ok then hs.alert.show("Window switch failed; try again") end
  end)
end

-- Registered hotkeys work with Secure Input.
cycle.hotkeys = {
  hs.hotkey.new({ "cmd" }, "`", function() selectNext(1) end),
  hs.hotkey.new({ "cmd", "shift" }, "`", function() selectNext(-1) end),
}
cycle.cancelKeys = {
  hs.hotkey.new({ "cmd" }, "escape", dismiss),
  hs.hotkey.new({ "cmd", "shift" }, "escape", dismiss),
}
-- Use flags from the event itself; background modifier polling can report stale state.
cycle.modifiers = hs.eventtap.new({ hs.eventtap.event.types.flagsChanged }, function(event)
  local code = event:getKeyCode()
  if session and (code == 54 or code == 55) then trace("command-event", { held = event:getFlags().cmd == true }) end
  if session and (code == 54 or code == 55) and not event:getFlags().cmd then finish() end
  return false
end):start()

local function updateHotkeys()
  local app = hs.application.frontmostApplication()
  if session and (not app or session.app:pid() ~= app:pid()) then dismiss("app-changed") end
  local menu = app and windowMenu(app)
  if session then
    local focused = app and app:focusedWindow()
    if not menu or (session.originID and (not focused or focused:id() ~= session.originID))
      or (not session.originID and menu.windows[menu.index] ~= session.entries[1].menu) then dismiss("menu-or-focus-changed") end
  end
  trace("menu-update", { pid = app and app:pid(), available = menu ~= nil, previouslyEnabled = cycle.hotkeys[1].enabled == true })
  if menu then remember(menu) end
  -- A transiently missing checkmark may recover without another AX window event.
  if not menu and app and knownByPID[app:pid()] then cycle.menuRetry:start()
  else cycle.menuRetry:stop() end
  for _, key in ipairs(cycle.hotkeys) do
    if menu then key:enable() else key:disable() end
  end
end
cycle.menuRetry = hs.timer.new(1, updateHotkeys)

function cycle.debugSnapshot()
  local app = hs.application.frontmostApplication()
  local menu = app and windowMenu(app)
  return { pid = app and app:pid(), menuAvailable = menu ~= nil,
    windows = menu and #menu.windows or 0, active = session ~= nil,
    forwardEnabled = cycle.hotkeys[1].enabled == true,
    reverseEnabled = cycle.hotkeys[2].enabled == true,
    modifierTap = cycle.modifiers:isEnabled(), secureInput = hs.eventtap.isSecureInputEnabled() }
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
cycle.watcher = hs.application.watcher.new(function(_, event, app)
  if event == hs.application.watcher.terminated and app then knownByPID[app:pid()] = nil end
  if event == hs.application.watcher.activated then trace("app-activated", { pid = app and app:pid() }); watchApp() end
end):start()
watchApp()
return cycle
