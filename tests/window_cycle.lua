-- Run from the repository root: lua tests/window_cycle.lua
local root = ... or "."
local pressed, alerts, hotkeys = {}, {}, {}
local activation
local app = { pid = function() return 1 end, bundleID = function() return "com.google.Chrome" end }
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
  axuielement = { applicationElement = function() return element({ AXMenuBar = bar }) end },
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
front = { pid = function() return 2 end, bundleID = function() return "com.apple.finder" end }
activation(nil, 1)
local count = #pressed
release(); assert(#pressed == count) -- Do not steal focus after changing apps.
assert(not hotkeys[1].enabled and not hotkeys[2].enabled) -- Native shortcuts elsewhere.
front = app; activation(nil, 1)
assert(hotkeys[1].enabled)
rows[5] = element({ AXTitle = "Other desktop" }, 3)
press(); release()
assert(#pressed == count and #alerts == 1) -- Missing selection is explicit, never guesses.
print("window_cycle: all checks passed")
