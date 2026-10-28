local profiles = require("window_cycle_profiles")
local overlay = {}
local canvas, icon

function overlay.hide()
  if canvas then canvas:delete(); canvas, icon = nil, nil end
end

function overlay.show(selection)
  local focused = selection.app:focusedWindow()
  local screen = focused and focused:screen() or hs.screen.mainScreen()
  local frame = screen:frame()
  local count = #selection.entries
  local visible = math.min(count, 7, math.max(1, math.floor((frame.w - 64) / 124)))
  local first = math.max(1, math.min(selection.index - math.floor(visible / 2), count - visible + 1))
  local width, height = math.max(208, visible * 124 + 32), 184
  local bounds = { x = frame.x + (frame.w - width) / 2, y = frame.y + (frame.h - height) / 2,
    w = width, h = height }
  if not canvas then
    canvas = hs.canvas.new(bounds):level("overlay")
      :behaviorAsLabels({ "canJoinAllSpaces", "stationary", "fullScreenAuxiliary" })
    icon = hs.image.imageFromAppBundle(selection.app:bundleID())
    profiles.attach(selection)
  else canvas:frame(bounds) end
  local elements = {
    { type = "rectangle", action = "strokeAndFill", roundedRectRadii = { xRadius = 20, yRadius = 20 },
      fillColor = { white = 0.12, alpha = 0.96 }, strokeColor = { white = 0.65, alpha = 0.35 },
      strokeWidth = 1, frame = { x = 1, y = 1, w = width - 2, h = height - 2 } },
  }
  local left = (width - visible * 124) / 2
  for i = first, first + visible - 1 do
    local x = left + (i - first) * 124
    if i == selection.index then
      elements[#elements + 1] = { type = "rectangle", action = "strokeAndFill",
        roundedRectRadii = { xRadius = 12, yRadius = 12 }, fillColor = { white = 1, alpha = 0.17 },
        strokeColor = { white = 1, alpha = 0.3 }, strokeWidth = 1,
        frame = { x = x + 3, y = 15, w = 118, h = 121 } }
    end
    if icon then
      elements[#elements + 1] = { type = "image", image = icon,
        frame = { x = x + 30, y = 25, w = 64, h = 64 } }
    end
    local profile = selection.entries[i].profile
    if profile and profile.image then
      local badge = { x = x + 73, y = 65, w = 30, h = 30 }
      elements[#elements + 1] = { type = "oval", action = "clip", frame = badge }
      elements[#elements + 1] = { type = "image", image = profile.image, frame = badge }
      elements[#elements + 1] = { type = "resetClip" }
      elements[#elements + 1] = { type = "oval", action = "stroke", frame = badge,
        strokeColor = { white = 0.15 }, strokeWidth = 2 }
    end
    elements[#elements + 1] = { type = "text", text = selection.entries[i].title,
      textSize = 12, textColor = { white = 0.95 }, textAlignment = "center", textLineBreak = "truncateTail",
      frame = { x = x + 9, y = 96, w = 106, h = 32 } }
  end
  local selected = selection.entries[selection.index]
  local title = selected.profile and selected.profile.name .. " — " .. selected.title or selected.title
  elements[#elements + 1] = { type = "text", text = title,
    textSize = 14, textColor = { white = 1 }, textAlignment = "center", textLineBreak = "truncateTail",
    frame = { x = 18, y = 145, w = width - 36, h = 19 } }
  elements[#elements + 1] = { type = "text", text = selection.index .. " of " .. count,
    textSize = 10, textColor = { white = 0.65 }, textAlignment = "center",
    frame = { x = 18, y = 166, w = width - 36, h = 13 } }
  canvas:replaceElements(elements):show()
end

return overlay
