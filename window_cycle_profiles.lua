local profiles = {}
local function text(value)
  return type(value) == "string" and value or ""
end

local function localName(profile)
  local label = text(profile.enterprise_label)
  return label ~= "" and label or text(profile.name)
end

local function accountName(profile)
  local given = text(profile.gaia_given_name)
  return given ~= "" and given or text(profile.gaia_name)
end

-- Match Chromium's profile display names, including duplicate given names.
local function displayName(profile, cache)
  local name, account = localName(profile), accountName(profile)
  if account == "" then return name end
  if account:lower() == name:lower() then return account end
  local showLocal = profile.is_using_default_name ~= true or text(profile.enterprise_label) ~= ""
  for _, other in pairs(cache) do
    if type(other) == "table" and other ~= profile and accountName(other) == account
      and (localName(other):lower() == account:lower() or other.is_using_default_name == true) then
      showLocal = true
    end
  end
  return showLocal and account .. " (" .. name .. ")" or account
end

local function leaf(value)
  return type(value) == "string" and value ~= "" and value ~= "." and value ~= ".."
    and not value:find("[/\\%z]")
end

function profiles.attach(selection)
  if selection.app:bundleID() ~= "com.google.Chrome" then return end
  local root = os.getenv("HOME") .. "/Library/Application Support/Google/Chrome/"
  local ok, state = pcall(hs.json.read, root .. "Local State")
  if not ok or type(state) ~= "table" or type(state.profile) ~= "table"
    or type(state.profile.info_cache) ~= "table" then return end
  local cache, rules = state.profile.info_cache, {}
  for directory, profile in pairs(cache) do
    if type(profile) == "table" then
      local name = displayName(profile, cache)
      local rule = { name = name, menuTitle = name, titleSuffix = " - Google Chrome - " .. name }
      if leaf(directory) and leaf(profile.gaia_picture_file_name)
        and (profile.use_gaia_picture == true or profile.is_using_default_avatar == true) then
        rule.imagePath = root .. directory .. "/" .. profile.gaia_picture_file_name
      end
      rules[#rules + 1] = rule
    end
  end
  local images = {}
  for _, entry in ipairs(selection.entries) do
    local title, match = entry.windowTitle, nil
    for _, rule in ipairs(rules) do
      if type(rule) == "table" and type(rule.name) == "string" and rule.name ~= "" then
        local named = type(rule.menuTitle) == "string" and rule.menuTitle ~= "" and entry.title == rule.menuTitle
        local suffixed = type(title) == "string" and type(rule.titleSuffix) == "string"
          and rule.titleSuffix ~= "" and title:sub(-#rule.titleSuffix) == rule.titleSuffix
        if named or suffixed then
          if match then match = nil; break end -- Ambiguous matches keep the app icon.
          match = rule
        end
      end
    end
    if match then
      local imagePath = match.imagePath
      if type(imagePath) == "string" and imagePath:sub(1, 1) == "/" then
        if images[imagePath] == nil then
          images[imagePath] = hs.image.imageFromPath(imagePath) or false
        end
        entry.profile = { name = match.name, image = images[imagePath] }
      end
    end
  end
end

return profiles
