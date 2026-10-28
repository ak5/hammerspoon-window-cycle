-- Run from the repository root: lua tests/window_cycle.lua
local root = ... or "."
local actions, alerts, hotkeys, windowWatchers = {}, {}, {}, {}
local activation, modifiers
local focused, space, missingCheck, failID = 1, 10, false, nil
local windows, menuRows = {}, {}
local function focus(id, kind)
  if failID == id then return nil end
  focused, space = id, windows[id].space
  actions[#actions + 1] = { id = id, kind = kind }
  return true
end
for id = 1, 3 do
  local window = { space = id == 3 and 20 or 10 }
  function window:id() return id end
  function window:isStandard() return true end
  function window:isMinimized() return false end
  function window:focus() return focus(id, "window") end
  windows[id] = window
  menuRows[id] = {
    attributeValue = function(_, name)
      if name == "AXTitle" then return "Identical title" end
      if name == "AXMenuItemMarkChar" and not missingCheck and focused == id then return "✓" end
    end,
    performAction = function(_, action) assert(action == "AXPress"); return focus(id, "menu") end,
  }
end
local function element(attrs)
  return { attributeValue = function(_, name) return attrs[name] end }
end
-- Deliberately put the remote window between the two local windows in menu order.
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
local mock = {
  application = {
    frontmostApplication = function() return front end,
    watcher = { activated = 1, new = function(fn)
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
  eventtap = { event = { types = { flagsChanged = 12 } }, new = function(events, fn)
    assert(#events == 1 and events[1] == 12) -- Never intercept ordinary/secure keystrokes.
    modifiers = fn; return { start = function(self) return self end }
  end },
  hotkey = { new = function(_, _, press, release, repeatfn)
    assert(repeatfn == nil)
    local key = { press = press, release = release }
    function key:enable() self.enabled = true end
    function key:disable() self.enabled = false end
    hotkeys[#hotkeys + 1] = key
    return key
  end },
}
assert(loadfile(root .. "/window_cycle.lua", "t", setmetatable({ hs = mock }, { __index = _G })))()
local function commandUp()
  assert(not modifiers({ getFlags = function() return {} end }))
end
local function reset(id)
  commandUp(); focused = id; space = windows[id].space
end
local function tap(expected, reverse)
  local key = hotkeys[reverse and 2 or 1]
  local count = #actions
  key.press(); assert(#actions == count) -- Switch only on grave-key release.
  key.release(); assert(actions[#actions].id == expected)
end
assert(hotkeys[1].enabled and hotkeys[2].enabled)
tap(2); assert(actions[#actions].kind == "window") -- Local first, despite menu order/duplicate titles.
tap(3); tap(1); tap(2) -- Holding Command gives A → B → C → A → B.
commandUp(); tap(1); tap(3); tap(2) -- A new hold from B gives B → A → C → B.
reset(1); tap(2, true); tap(3, true); tap(1, true) -- Reverse also visits locals first.
reset(3); tap(1); tap(2); tap(3) -- One local window crosses immediately.
reset(1); tap(2); focused = 1; space = 10; tap(2) -- Manual focus changes start a fresh sequence.
reset(1); windows[2].isMinimized = function() return true end
tap(3); windows[2].isMinimized = function() return false end -- Minimized windows are not local-first.
reset(1); hotkeys[1].press(); commandUp(); hotkeys[1].release()
assert(focused == 2); tap(1) -- Releasing Command before grave still completes the pending switch.
reset(1); hotkeys[1].press()
front = application(2, true); activation(nil, 1)
local count = #actions
hotkeys[1].release(); assert(#actions == count)
assert(not hotkeys[1].enabled and not hotkeys[2].enabled)
assert(windowWatchers[1].stopped)
front = application(3); activation(nil, 1)
assert(hotkeys[1].enabled); reset(1); tap(2) -- Arbitrary apps work without an allowlist.
front = app; activation(nil, 1); reset(1)
missingCheck = true; count = #actions
hotkeys[1].press(); hotkeys[1].release()
assert(#actions == count and #alerts == 1)
windowWatchers[#windowWatchers].callback(); assert(not hotkeys[1].enabled)
missingCheck = false
windowWatchers[#windowWatchers].callback(); assert(hotkeys[1].enabled)
reset(1); failID = 2
hotkeys[1].press(); hotkeys[1].release(); assert(#alerts == 2 and focused == 1)
failID = nil; tap(2) -- A failed switch resets the sequence.
front = nil; activation(nil, 1)
assert(not hotkeys[1].enabled and not hotkeys[2].enabled)
print("window_cycle: all checks passed")
