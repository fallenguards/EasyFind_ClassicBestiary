-- Loads the addon's toc files against a stubbed game and a recording EasyFind.API, then checks what it
-- registered. Usage: lua smoke_test.lua <addon dir> <toc> <addon name> [mode]
-- Modes: normal; noapi (no EasyFind); oldapi (EasyFind before API 1.6, no creature ids on rows);
-- nobestiary (Classic Bestiary not installed); oldbestiary (one before its API); newbestiary (an API
-- version this extension does not know).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122 212
local dir, tocName, addon, mode = arg[1], arg[2], arg[3], arg[4] or "normal"

local Stub
local stubMeta = {}
stubMeta.__index = function(t, k)
    if k == "GetName" then return function() return nil end end
    if k == "IsShown" or k == "IsVisible" then return function() return false end end
    local v = Stub()
    rawset(t, k, v)
    return v
end
stubMeta.__call = function() return Stub() end
function Stub() return setmetatable({}, stubMeta) end

local frames = {}
local function NewFrame()
    local f = Stub()
    local scripts, events = {}, {}
    rawset(f, "SetScript", function(self, which, fn) scripts[which] = fn end)
    rawset(f, "RegisterEvent", function(self, e) events[e] = true end)
    rawset(f, "UnregisterEvent", function(self, e) events[e] = nil end)
    f.scripts, f.events = scripts, events
    frames[#frames + 1] = f
    return f
end

local toc = assert(io.open(dir .. "/" .. tocName)):read("a")

local env = setmetatable({}, { __index = function(t, k)
    local v = rawget(_G, k)
    if v ~= nil or k:match("^[A-Z][A-Z0-9_]+$") then return v end
    v = Stub()
    rawset(t, k, v)
    return v
end })
_G.CreateFrame = NewFrame
_G.GetLocale = function() return "enUS" end
_G.C_Spell = {
    GetSpellName = function(id) return "Spell " .. id end,
    GetSpellTexture = function(id) return 135000 + id end,
}
-- Loaded beside Classic Bestiary (OptionalDeps): the file returns at once without it.
_G.C_AddOns = { IsAddOnLoaded = function(name) return name == "ClassicBestiary" and mode ~= "nobestiary" end }

local printed = {}
_G.print = function(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[i] = tostring(select(i, ...)) end
    printed[#printed + 1] = table.concat(parts, " ")
end
local function Say(s) io.stdout:write(s, "\n") end

-- EasyFind.API as an extension sees it, every registration kept.
local registered = { extensions = {}, decorators = {} }
if mode ~= "noapi" then
    local API = { VERSION = 1, MINOR = mode == "oldapi" and 5 or 6 }
    function API.RegisterExtension(def) registered.extensions[def.id] = def return true end
    function API.RegisterRowDecorator(def) registered.decorators[def.id] = def return true end
    _G.EasyFind = { API = API, db = {} }
end
-- Classic Bestiary's API: creature 1234 casts two spells, every other none.
if mode == "oldbestiary" then
    _G.ClassicBestiary = {}
elseif mode ~= "nobestiary" then
    _G.ClassicBestiary = {
        API_VERSION = mode == "newbestiary" and 2 or 1,
        IterateAbilities = function(npcID)
            local list, i = npcID == 1234 and { 100, 101 } or {}, 0
            return function() i = i + 1 return list[i] end
        end,
    }
end

local ns = {}
local count = 0
for line in toc:gmatch("[^\r\n]+") do
    if line:match("%.lua$") and not line:match("^#") then
        local path = dir .. "/" .. line:gsub("\\", "/")
        local chunk, err = loadfile(path, "t", env)
        if not chunk then Say("LOAD " .. err) os.exit(1) end
        local ok, runErr = pcall(chunk, addon, ns)
        if not ok then Say("RUN " .. line .. ": " .. tostring(runErr)) os.exit(1) end
        count = count + 1
    end
end
Say("loaded " .. count .. " files (" .. mode .. ")")

local failed = false
local function Check(ok, what)
    Say((ok and "PASS " or "FAIL ") .. what)
    if not ok then failed = true end
end

for i = 1, #frames do
    local f = frames[i]
    if f.scripts.OnEvent then
        local ok, err = pcall(f.scripts.OnEvent, f, "PLAYER_LOGIN")
        if not ok then Check(false, "PLAYER_LOGIN: " .. tostring(err)) end
    end
end

local ext, decorator = registered.extensions.classicbestiary, registered.decorators.classicbestiary
if mode == "noapi" or mode == "nobestiary" then
    Check(ext == nil and decorator == nil, "nothing registered without EasyFind or Classic Bestiary")
elseif mode == "oldapi" then
    Check(ext ~= nil and decorator == nil, "the extension alone on an EasyFind before API 1.6")
    Check(printed[1] ~= nil and printed[1]:find("needs an update", 1, true) ~= nil, "says EasyFind needs an update")
elseif mode == "oldbestiary" or mode == "newbestiary" then
    Check(ext ~= nil and decorator == nil, "the extension alone with a Classic Bestiary it does not know")
    Check(printed[1] ~= nil and printed[1]:find("not one the extension knows", 1, true) ~= nil,
        "says which versions to update")
else
    Check(ext ~= nil and type(ext.name) == "string" and ext.icon ~= nil and type(ext.settings) == "function",
        "the extension, with its name, icon and settings page")
    Check(decorator ~= nil and type(decorator.applies) == "function" and type(decorator.tooltip) == "function",
        "its row decorator, with applies and tooltip")
    Check(#printed == 0, "nothing printed at login")
    if decorator then
        local ok, takes = pcall(decorator.applies, { name = "Hogger" })
        Check(ok and takes == false, "a row with no creature id is left alone")
        ok, takes = pcall(decorator.applies, { npcID = 99 })
        Check(ok and takes == false, "a creature the Bestiary has nothing for is left alone")
        ok, takes = pcall(decorator.applies, { npcID = 1234 })
        Check(ok and takes == true, "a creature with abilities is taken")
        local tip = { lines = {} }
        function tip:AddLine(text) self.lines[#self.lines + 1] = text end
        ok = pcall(decorator.tooltip, { npcID = 1234 }, nil, tip)
        Check(ok and #tip.lines == 4 and tip.lines[3]:find("Spell 100", 1, true) ~= nil,
            "its tooltip: a blank, the header and the two abilities")
    end
end
os.exit(failed and 1 or 0)
