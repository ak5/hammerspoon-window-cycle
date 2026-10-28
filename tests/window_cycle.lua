-- Run from the repository root: lua tests/window_cycle.lua
local root = ... or "."
local actions, alerts, hotkeys, windowWatchers, timers = {}, {}, {}, {}, {}
local activation, modifiers, preview, menuRetry
local focused, space, missingCheck, failID = 1, 10, false, nil
local windows, menuRows = {}, {}
local titles = { "Window A", "Window B", "Window C" }
local function focus(id)
  if failID == id then return nil end
  focused, space = id, windows[id].space
  actions[#actions + 1] = id
  return true
end
for id = 1, 3 do
  local window = { space = id == 3 and 20 or 10 }
  function window:id() return id end
  function window:title() return titles[id] .. " - App profile" end
  function window:isStandard() return true end
  function window:isMinimized() return false end
  windows[id] = window
  menuRows[id] = {
    attributeValue = function(_, name)
      if name == "AXTitle" then return titles[id] end
      if name == "AXMenuItemMarkChar" and not missingCheck and focused == id then return "✓" end
    end,
    performAction = function(_, action) assert(action == "AXPress"); return focus(id) end,
  }
end
local function element(attrs)
  return { attributeValue = function(_, name) return attrs[name] end }
end
-- Remote C precedes local B in menu order.
local rows = { element({ AXTitle = "Minimize" }), element({ AXTitle = "" }),
  menuRows[1], menuRows[3], menuRows[2] }
local bar = element({ AXChildren = { element({ AXTitle = "Window", AXChildren = {
  element({ AXChildren = rows }),
} }) } })
local function application(pid, noMenu)
  return {
    pid = function() return pid end,
    noMenu = noMenu,
    focusedWindow = function() return windows[focused] end,
    allWindows = function() return windows end,
    newWatcher = function(_, fn)
      local watcher = { callback = fn, stopped = false }
      function watcher:start() return self end
      function watcher:stop() self.stopped = true end
      windowWatchers[#windowWatchers + 1] = watcher
      return watcher
    end,
  }
end
local app = application(1)
local front = app
local mockOverlay = {
  show = function(selection) preview = selection end,
  hide = function() preview = nil end,
}
local mock = {
  application = {
    frontmostApplication = function() return front end,
    watcher = { activated = 1, terminated = 2, new = function(fn)
      activation = fn; return { start = function(self) return self end }
    end },
  },
  axuielement = { applicationElement = function(a)
    if a.noMenu then return element({}) end
    return element({ AXMenuBar = bar })
  end },
  spaces = { focusedSpace = function() return space end,
    windowSpaces = function(w) return { w.space } end },
  uielement = { watcher = { focusedWindowChanged = "focus", windowCreated = "created" } },
  alert = { show = function(message) alerts[#alerts + 1] = message end },
  timer = { secondsSinceEpoch = function() return 1 end, doAfter = function(_, fn) timers[#timers + 1] = fn end,
    new = function(interval, fn)
      assert(interval == 1)
      menuRetry = { callback = fn, running = false }
      function menuRetry:start() self.running = true; return self end
      function menuRetry:stop() self.running = false; return self end
      return menuRetry
    end,
  },
  eventtap = {
    checkKeyboardModifiers = function() error("Background modifier polling must not control release") end,
    event = { types = { flagsChanged = 12 } },
    new = function(events, fn)
      assert(#events == 1 and events[1] == 12)
      modifiers = fn; return { start = function(self) return self end }
    end,
  },
  hotkey = { new = function(_, keyName, press, release, repeatfn)
    assert(release == nil and repeatfn == nil)
    local key = { press = press, name = keyName }
    function key:enable() self.enabled = true end
    function key:disable() self.enabled = false end
    hotkeys[#hotkeys + 1] = key
    return key
  end },
}
local env = setmetatable({ hs = mock, require = function(name)
  assert(name == "window_cycle_overlay"); return mockOverlay
end }, { __index = _G })
local cycle = assert(loadfile(root .. "/window_cycle.lua", "t", env))()
cycle.tracing = true
local function flush()
  local queued = timers; timers = {}
  for _, fn in ipairs(queued) do fn() end
end
local function modifier(code, held)
  assert(not modifiers({ getKeyCode = function() return code end,
    getFlags = function() return { cmd = held } end }))
end
local function commandUp(code)
  modifier(code or 55, false); flush()
end
local function reset(id)
  hotkeys[3].press(); focused = id; space = windows[id].space
  windowWatchers[#windowWatchers].callback()
end
local function tap(expected, reverse)
  local count, before = #actions, focused
  hotkeys[reverse and 2 or 1].press()
  assert(#actions == count and focused == before) -- Preview never focuses a window.
  assert(preview and preview.entries[preview.index].menu == menuRows[expected])
  modifier(55, true) -- Holding Command never commits.
  modifier(56, false) -- An unrelated modifier event cannot be interpreted as Command-up.
  flush()
  assert(#actions == count and focused == before)
end
assert(hotkeys[1].enabled and hotkeys[2].enabled)
tap(2); tap(3); tap(1); tap(2)
assert(hotkeys[3].enabled and hotkeys[4].enabled)
commandUp(); commandUp(); assert(focused == 2 and #actions == 1 and preview == nil)
assert(not hotkeys[3].enabled and not hotkeys[4].enabled)
tap(1); tap(3); commandUp(54); assert(focused == 3) -- Right Command also commits. A new hold starts on the new desktop.
reset(1); tap(2); tap(1, true); commandUp(); assert(focused == 1) -- Shift reverses the highlight.
reset(1); tap(2, true); tap(3, true); commandUp(); assert(focused == 3)
reset(3); tap(1); tap(2); tap(3); commandUp(); assert(focused == 3)
reset(1); tap(2); local count = #actions
hotkeys[3].press(); commandUp(); assert(#actions == count and preview == nil) -- Escape cancels.
reset(1); tap(2); focused = 3; space = 20
windowWatchers[#windowWatchers].callback(); commandUp()
assert(#actions == count and preview == nil) -- Clicking another window cancels the preview.
reset(1); tap(2)
front = application(2, true); activation(nil, 1)
commandUp(); assert(#actions == count and preview == nil)
assert(not hotkeys[1].enabled and windowWatchers[1].stopped)
front = application(3); activation(nil, 1); reset(1); tap(2); commandUp(); assert(focused == 2)
-- If focus changes after release but before the queued action, do not steal it back.
reset(1); tap(2)
modifier(55, false)
front = application(4, true); flush(); assert(focused == 1)
front = app; activation(nil, 1); reset(1)
missingCheck = true; windowWatchers[#windowWatchers].callback()
assert(not hotkeys[1].enabled and menuRetry.running)
menuRetry.callback(); assert(not hotkeys[1].enabled and menuRetry.running)
-- Menu returns without any window/app event: the retry must restore the shortcut.
missingCheck = false; menuRetry.callback()
assert(hotkeys[1].enabled and not menuRetry.running)
missingCheck = true; windowWatchers[#windowWatchers].callback(); assert(menuRetry.running)
front = application(99, true); activation(nil, 1)
assert(not hotkeys[1].enabled and not menuRetry.running) -- Unsupported apps do not poll.
front = app; missingCheck = false; activation(nil, 1)
reset(1); failID = 2; tap(2); commandUp(); assert(#alerts == 1 and focused == 1)
failID = nil; tap(2); commandUp(); assert(focused == 2)
-- Rebuilding menu objects during preview must neither cancel nor select a stale row.
reset(1); tap(2)
local oldFirst, oldLast = rows[3], rows[5]
rows[3] = { attributeValue = oldFirst.attributeValue, performAction = oldFirst.performAction }
rows[5] = { attributeValue = oldLast.attributeValue, performAction = oldLast.performAction }
windowWatchers[#windowWatchers].callback()
assert(preview)
commandUp(); assert(focused == 2)
rows[3], rows[5] = oldFirst, oldLast
-- Reusing a menu row must not reuse its former window's profile or desktop.
reset(1); reset(2); reset(1)
local originalAttribute = menuRows[2].attributeValue
menuRows[2].attributeValue = function(self, name)
  if name == "AXTitle" then return "Different remote window" end
  return originalAttribute(self, name)
end
tap(3); tap(2)
assert(preview.entries[preview.index].windowID == nil and preview.entries[preview.index].windowTitle == nil)
hotkeys[3].press(); menuRows[2].attributeValue = originalAttribute
-- Visited, uniquely titled remote windows retain their identity after app changes.
reset(3); front = application(4, true); activation(nil, 1)
front = app; activation(nil, 1); reset(1); tap(2); tap(3)
assert(preview.entries[preview.index].windowTitle == "Window C - App profile")
commandUp()
activation(nil, 2, app)
reset(1); tap(2); tap(3); assert(preview.entries[preview.index].windowTitle == nil); commandUp()
-- Duplicate titles cannot safely identify another window's profile, even after visits.
titles = { "Same", "Same", "Same" }
reset(2); reset(3); reset(1); tap(3)
assert(preview.entries[preview.index].windowTitle == nil)
commandUp()
-- Unobserved ambiguous titles stay separate in menu order, without guessing a desktop.
front = application(5); activation(nil, 1); reset(1); tap(3); tap(2)
commandUp(); assert(focused == 2)
front = nil; activation(nil, 1)
assert(not hotkeys[1].enabled and not hotkeys[2].enabled)
assert(#cycle.trace > 0 and #cycle.trace <= 200)
for _, entry in ipairs(cycle.trace) do
  for key, value in pairs(entry) do
    assert(type(value) == "boolean" or type(value) == "number" or key == "event" or key == "reason")
  end
end
print("window_cycle: all checks passed")
