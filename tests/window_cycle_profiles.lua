-- Run from the repository root: lua tests/window_cycle_profiles.lua
local root = ... or "."
local cache, reads, loads = {}, 0, 0
local state = { profile = { info_cache = cache } }
local base = "/test/Library/Application Support/Google/Chrome/"
local mock = {
  json = { read = function(path)
    reads = reads + 1; assert(path == base .. "Local State")
    if state == "error" then error("permission denied") end
    return state
  end },
  image = { imageFromPath = function(path)
    loads = loads + 1
    assert(path:sub(1, #base) == base and not path:find("%.%./"))
    if path:find("missing.png", 1, true) then return nil end
    return path
  end },
}
local profiles = assert(loadfile(root .. "/window_cycle_profiles.lua", "t",
  setmetatable({ hs = mock, os = { getenv = function() return "/test" end } }, { __index = _G })))()
local function profile(name, given, default)
  return { name = name, gaia_given_name = given, is_using_default_name = default,
    is_using_default_avatar = true, gaia_picture_file_name = "avatar.png" }
end
local app = { bundleID = function() return "com.google.Chrome" end }
local function attach(entries)
  profiles.attach({ app = app, entries = entries })
  return entries
end
cache.Default = profile("Sam", "Sam", true)
cache.Work = profile("Work", "Sam", false)
cache.Person = profile("Person 2", "Sam", true)
cache.Study = profile("Study", "", false)
local entries = attach({ { title = "Sam" }, { title = "Sam (Work)" },
  { title = "Sam (Person 2)" }, { title = "Study" }, { title = "Unknown" },
  { windowTitle = "Page - Google Chrome - Sam" } })
assert(entries[1].profile.image == base .. "Default/avatar.png")
assert(entries[2].profile.image == base .. "Work/avatar.png")
assert(entries[3].profile.name == "Sam (Person 2)" and entries[4].profile.name == "Study")
assert(not entries[5].profile and entries[6].profile.image == entries[1].profile.image)
assert(reads == 1 and loads == 4) -- Once per preview; images reused within it.
assert(not attach({ { title = "Sam", windowTitle = "Page - Google Chrome - Sam (Work)" } })[1].profile)
assert(not attach({ { title = "Sam - extra" } })[1].profile)
cache.Duplicate = profile("Sam", "Sam", true)
assert(not attach({ { title = "Sam" } })[1].profile)
cache.Duplicate = nil
cache.Work.gaia_picture_file_name = "../secret.png"
cache.Person.gaia_picture_file_name = "/absolute.png"
cache.Study.is_using_default_avatar = false
cache["../outside"] = profile("Outside", "", false)
local before = loads
for _,entry in ipairs(attach({{title="Sam (Work)"},{title="Sam (Person 2)"},{title="Study"},{title="Outside"}})) do
  assert(not entry.profile)
end
assert(loads == before)
cache.Enterprise = profile("Old", "Lee", false)
cache.Enterprise.enterprise_label = "Team"
assert(attach({{title="Lee (Team)"}})[1].profile)
cache.Default.gaia_picture_file_name = "missing.png"
assert(not attach({{title="Sam"}})[1].profile.image)
cache.Study.use_gaia_picture = true
assert(attach({{title="Study"}})[1].profile.image)
cache.Bad = false
assert(not attach({{} })[1].profile)
for _,bad in ipairs({false, {}, {profile=true}, {profile={info_cache="bad"}}, "error"}) do
  state=bad; assert(not attach({{title="Sam"}})[1].profile)
end
before=reads
profiles.attach({app={bundleID=function() return "other.app" end},entries={}})
assert(reads==before)
print("window_cycle_profiles: all checks passed")
