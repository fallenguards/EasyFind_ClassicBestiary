-- Classic Bestiary's creature abilities on EasyFind's rows: hovering an NPC
-- or boss row lists what it casts, read through the Bestiary's API at the
-- moment of the hover; none of its data is copied.
local _, ns = ...
local API = EasyFind and EasyFind.API
if not (API and API.VERSION == 1) then return end

local L = ns.L
-- Loaded beside Classic Bestiary (OptionalDeps), nothing without it.
local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
if not (IsAddOnLoaded and IsAddOnLoaded("ClassicBestiary")) then return end
local KEY = "classicbestiary"
local ICON = "Interface\\AddOns\\EasyFind_ClassicBestiary\\bestiary"
ns.KEY = KEY

local sformat = string.format
local SpellName = C_Spell and C_Spell.GetSpellName
    or (GetSpellInfo and function(id) return (GetSpellInfo(id)) end)
local SpellIcon = C_Spell and C_Spell.GetSpellTexture or GetSpellTexture
local DEFAULT_LINES = 8

function ns.Print(text)
    print(sformat("|cff66ccff%s:|r %s", L["EXT_NAME"], text))
end

local function Bestiary() return _G.ClassicBestiary end

-- The player's switches, in EasyFind's own saved data.
local function Store()
    local db = EasyFind.db
    db.classicBestiary = db.classicBestiary or {}
    return db.classicBestiary
end
local function Enabled() return Store().off ~= true end
local function MaxLines() return Store().lines or DEFAULT_LINES end

-- The creature a row stands for: an NPC on the map or a boss, by creature id.
local function NpcOf(row)
    local id = row.npcID
    return type(id) == "number" and id > 0 and id or nil
end

-- A row with a creature the Bestiary lists abilities for.
local function Applies(row)
    if not Enabled() then return false end
    local id = NpcOf(row)
    local CB = Bestiary()
    if not (id and CB and CB.IterateAbilities) then return false end
    local nextAbility = CB.IterateAbilities(id)
    return nextAbility() ~= nil
end

local function Tooltip(row, _, tooltip)
    local id = NpcOf(row)
    local CB = Bestiary()
    if not (id and CB and CB.IterateAbilities) then return end
    local max = MaxLines()
    local shown, more = 0, 0
    for spellID in CB.IterateAbilities(id) do
        local name = SpellName and SpellName(spellID)
        if name and name ~= "" then
            if max > 0 and shown >= max then
                more = more + 1
            else
                if shown == 0 then
                    tooltip:AddLine(" ")
                    tooltip:AddLine(L["TT_HEADER"], 1, 0.82, 0)
                end
                local icon = SpellIcon and SpellIcon(spellID)
                tooltip:AddLine(icon and sformat("|T%s:14:14:0:0|t %s", icon, name) or name, 1, 1, 1)
                shown = shown + 1
            end
        end
    end
    if more > 0 then tooltip:AddLine(sformat(L["TT_MORE_FMT"], more), 0.6, 0.6, 0.6) end
end
ns.Applies, ns.Tooltip = Applies, Tooltip

-- The Extensions tab's page: the switch and how many lines a tooltip lists.
local LINE_CHOICES = { { label = "4", value = 4 }, { label = "8", value = 8 }, { label = "12", value = 12 },
                       { label = L["OPT_LINES_ALL"], value = 0 } }
local function Settings(page, kit)
    local below = kit.Title(page, L["EXT_NAME"], L["SETTINGS_HINT"])
    local box = kit.Checkbox(page, L["OPT_SHOW"], Enabled, function(on)
        if on then Store().off = nil else Store().off = true end
    end)
    box:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, -8)
    local lines = kit.Choice(page, L["OPT_LINES"], LINE_CHOICES, MaxLines, function(v) Store().lines = v end,
        nil, DEFAULT_LINES)
    lines:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -8)
end
ns.Settings = Settings

API.RegisterExtension({
    id = KEY,
    name = L["EXT_NAME"],
    description = L["EXT_DESC"],
    icon = ICON,
    keywords = { "bestiary", "abilities", "creature", "mob" },
    settings = Settings,
})

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    local CB = Bestiary()
    if not (CB and CB.API_VERSION == 1 and CB.IterateAbilities) then
        ns.Print(L["NOT_READY_BESTIARY"])
        return
    end
    if not API.RegisterRowDecorator then
        ns.Print(L["NOT_READY_EASYFIND"])
        return
    end
    API.RegisterRowDecorator({ id = KEY, label = L["EXT_NAME"], applies = Applies, tooltip = Tooltip })
    ns.ready = true
end)
