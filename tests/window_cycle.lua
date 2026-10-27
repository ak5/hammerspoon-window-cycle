-- Run from the repository root: lua tests/window_cycle.lua
local root = ... or "."
local pressed, alerts, hotkeys = {}, {}, {}
local activation
local windowWatchers = {}
local function application(pid, noMenu)
  return {
    pid = function() return pid end,
    noMenu = noMenu,
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
local function element(attrs, id)
  return {
    attributeValue = function(_, name) return attrs[name] end,
    performAction = function(_, action) assert(action == "AXPress"); pressed[#pressed + 1] = id; return true end,
  }
end
local rows = {
  element({ AXTitle = "Minimize" }), element({ AXTitle = "" }),
  element({ AXTitle = "Same title", AXMenuItemMarkChar = "✓" }, 1),
  element({ AXTitle = "Same title" }, 2), element({ AXTitle = "Other desktop" }, 3),
}
local bar = element({ AXChildren = { element({ AXTitle = "Window", AXChildren = {
  element({ AXChildren = rows }),
} }) } })
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
  uielement = { watcher = { focusedWindowChanged = "focus", windowCreated = "created" } },
  alert = { show = function(message) alerts[#alerts + 1] = message end },
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
local function press(index) hotkeys[index or 1].press() end
local function release(index) hotkeys[index or 1].release() end
assert(hotkeys[1].enabled and hotkeys[2].enabled)
press(); assert(#pressed == 0) -- No focus change until the grave key is released.
release(); assert(pressed[#pressed] == 2) -- Duplicate titles select distinct items.
press(2); release(2); assert(pressed[#pressed] == 3) -- Reverse wraps across desktops.
rows[3] = element({ AXTitle = "Same title" }, 1)
rows[5] = element({ AXTitle = "Other desktop", AXMenuItemMarkChar = "✓" }, 3)
press(); release(); assert(pressed[#pressed] == 1) -- Forward wraps.
press()
front = application(2, true)
activation(nil, 1)
local count = #pressed
release(); assert(#pressed == count) -- Do not steal focus after changing apps.
assert(not hotkeys[1].enabled and not hotkeys[2].enabled) -- Native shortcuts elsewhere.
assert(windowWatchers[1].stopped) -- Only watch the current app.
front = application(3); activation(nil, 1)
assert(hotkeys[1].enabled) -- An arbitrary app works without a bundle-ID allowlist.
press(); release(); assert(pressed[#pressed] == 1)
count = #pressed
front = app; activation(nil, 1)
assert(hotkeys[1].enabled)
rows[5] = element({ AXTitle = "Other desktop" }, 3)
press(); release()
assert(#pressed == count and #alerts == 1) -- Missing selection is explicit, never guesses.
windowWatchers[#windowWatchers].callback()
assert(not hotkeys[1].enabled) -- An app without a checked window keeps native cycling.
rows[5] = element({ AXTitle = "Other desktop", AXMenuItemMarkChar = "✓" }, 3)
windowWatchers[#windowWatchers].callback()
assert(hotkeys[1].enabled) -- A new/focused window enables cycling without switching apps.
front = nil; activation(nil, 1)
assert(not hotkeys[1].enabled and not hotkeys[2].enabled)
print("window_cycle: all checks passed")
