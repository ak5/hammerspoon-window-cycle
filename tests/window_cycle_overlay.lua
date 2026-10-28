-- Run from the repository root: lua tests/window_cycle_overlay.lua
local root = ... or "."
local frame, elements, visible, deleted, creations
local screenWidth = 1440
local canvas = {}
function canvas:level() return self end
function canvas:behaviorAsLabels() return self end
function canvas:frame(value) frame = value; return self end
function canvas:replaceElements(value) elements = value; return self end
function canvas:show() visible = true; return self end
function canvas:delete() visible, deleted = false, true end
local mock = {
  canvas = { new = function(bounds) frame = bounds; creations = (creations or 0) + 1; return canvas end },
  screen = { mainScreen = function() return { frame = function() return { x = 0, y = 0, w = screenWidth, h = 900 } end } end },
  image = { imageFromAppBundle = function() return "icon" end },
}
local overlay = assert(loadfile(root .. "/window_cycle_overlay.lua", "t",
  setmetatable({ hs = mock, require = function(name)
    assert(name == "window_cycle_profiles")
    return { attach = function(selection)
      selection.entries[1].profile = { name = "Work", image = "avatar" }
    end }
  end }, { __index = _G })))()
local app = { focusedWindow = function() return nil end, bundleID = function() return "example.app" end }
local entries = {}
for i = 1, 20 do entries[i] = { title = "Window " .. i } end
overlay.show({ app = app, entries = entries, index = 19 })
assert(visible and frame.x >= 0 and frame.x + frame.w <= screenWidth)
local icons, highlights = 0, 0
for _, e in ipairs(elements) do
  if e.type == "image" then icons = icons + 1 end
  if e.type == "rectangle" and e.roundedRectRadii.xRadius == 12 then highlights = highlights + 1 end
end
assert(icons == 7 and highlights == 1)
assert(elements[#elements - 1].text == "Window 19" and elements[#elements].text == "19 of 20")
screenWidth = 480
overlay.show({ app = app, entries = entries, index = 1 })
assert(creations == 1 and frame.x >= 0 and frame.x + frame.w <= screenWidth)
assert(elements[#elements - 1].text == "Work — Window 1")
local badges, clips, resets = 0, 0, 0
for _, e in ipairs(elements) do
  if e.type == "image" and e.image == "avatar" then badges = badges + 1 end
  if e.action == "clip" then
    assert(e.type == "oval" and e.frame.w == 30 and e.frame.h == 30)
    clips = clips + 1
  end
  if e.type == "resetClip" then resets = resets + 1 end
end
assert(badges == 1 and clips == 1 and resets == 1)
overlay.hide(); assert(deleted and not visible)
overlay.show({ app = app, entries = { entries[1] }, index = 1 })
assert(creations == 2 and visible)
overlay.hide()
print("window_cycle_overlay: all checks passed")
