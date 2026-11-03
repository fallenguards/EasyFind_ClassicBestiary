-- Bestiary.lua against a stand-in Classic Bestiary and EasyFind API: what
-- registers, which rows the decorator takes, the tooltip's lines with and
-- without the details key, and the settings page's switches.
-- Run: lua tests/test_bestiary.lua
local ROOT = (arg and arg[0] or ""):match("^(.-)tests[/\\]") or "./"

-- The Bestiary's API: creature 10 casts three spells, 20 nothing, 30 twelve.
-- Shadow Bolt sets off Shadow Vulnerability; Curse of Weakness has no text
-- of its own but sets off a spell of the same name that has.
local abilities = { [10] = { 100, 101, 102 }, [20] = {}, [30] = {} }
for i = 1, 12 do abilities[30][i] = 200 + i end
local relationships = { [101] = { { s = 150, k = 1 } }, [102] = { { s = 160, k = 1 } } }
ClassicBestiary = {
    API_VERSION = 1,
    IterateAbilities = function(npcID)
        local list, i = abilities[npcID], 0
        return function()
            if not list then return nil end
            i = i + 1
            if list[i] then return list[i], "accepted" end
        end
    end,
    GetRelationships = function(spellID) return relationships[spellID] or {}, "classified" end,
}
ClassicBestiaryCfg = {}

-- The client: spell names, icons and texts, the held keys, an addon list.
local names = { [100] = "Infected Bite", [101] = "Shadow Bolt", [102] = "Curse of Weakness",
                [150] = "Shadow Vulnerability", [160] = "Curse of Weakness", [300] = "Late Spell" }
local texts = { [100] = "Infects the target.", [101] = "Hurls a bolt of shadow.", [150] = "Shadow damage taken increased.",
                [160] = "Melee attack power reduced." }
for i = 1, 12 do names[200 + i] = "Spell " .. i end
local cached = {}
C_Spell = {
    GetSpellName = function(id) return names[id] end,
    GetSpellTexture = function(id) return 1000 + id end,
    GetSpellDescription = function(id) return texts[id] or "" end,
    IsSpellDataCached = function(id) return cached[id] ~= false end,
    DoesSpellExist = function(id) return names[id] ~= nil end,
}
local keys = { ctrl = false, shift = false, alt = false }
function IsControlKeyDown() return keys.ctrl end
function IsShiftKeyDown() return keys.shift end
function IsAltKeyDown() return keys.alt end
local loads, timers = {}, {}
Spell = { CreateFromSpellID = function(_, id)
    return { ContinueOnSpellLoad = function(_, fn) loads[#loads + 1] = { id = id, fn = fn } end }
end }
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
C_AddOns = { IsAddOnLoaded = function(name) return name == "ClassicBestiary" end }
local handlers = {}
function CreateFrame()
    return { RegisterEvent = function() end, UnregisterEvent = function() end,
             SetScript = function(_, _, fn) handlers[#handlers + 1] = fn end }
end
local printed = {}
print = function(...) printed[#printed + 1] = table.concat({ ... }, " ") end

-- EasyFind's API and saved data: what the extension registers lands here.
local registered, redraws = {}, 0
EasyFind = { db = {}, API = {
    VERSION = 1, MINOR = 8,
    RegisterExtension = function(def) registered.extension = def return true end,
    RegisterRowDecorator = function(def) registered.decorator = def return true end,
    RedrawRowTooltip = function() redraws = redraws + 1 end,
} }

local function LoadAddon()
    local ns = {}
    assert(loadfile(ROOT .. "Locales/enUS.lua"))("EasyFind_ClassicBestiary", ns)
    assert(loadfile(ROOT .. "Bestiary.lua"))("EasyFind_ClassicBestiary", ns)
    for _, fn in ipairs(handlers) do fn({ UnregisterEvent = function() end }, "PLAYER_LOGIN") end
    return ns
end

local function Tip()
    local tip = { lines = {} }
    function tip:AddLine(text) self.lines[#self.lines + 1] = text end
    return tip
end

local function Lines(ns, npcID)
    local tip = Tip()
    ns.Tooltip({ npcID = npcID }, nil, tip)
    return tip.lines
end

-- The settings kit: each control remembers its getter and setter.
local function Kit()
    local made = {}
    local function Control(kind, get, set)
        local c = { kind = kind, get = get, set = set }
        function c:SetPoint() end
        made[#made + 1] = c
        return c
    end
    return {
        made = made,
        Title = function() return Control("title") end,
        Checkbox = function(_, _, get, set) return Control("checkbox", get, set) end,
        Choice = function(_, _, _, get, set) return Control("choice", get, set) end,
    }
end

local failures = 0
local function check(cond, what)
    if cond then io.write("  ok   ", what, "\n") else failures = failures + 1 io.write("  FAIL ", what, "\n") end
end
local function has(lines, text)
    for _, line in ipairs(lines) do
        if line:find(text, 1, true) then return true end
    end
    return false
end

local ns = LoadAddon()
check(registered.extension and registered.extension.id == "classicbestiary", "the extension registers")
check(registered.extension.icon:find("bestiary", 1, true) ~= nil, "with its own glyph")
check(registered.extension.settings == ns.Settings, "its tile opens its settings page")
check(registered.decorator and registered.decorator.tooltip == ns.Tooltip, "a tooltip decorator registers at login")
check(registered.decorator.modifiers == true, "drawn again as a key goes down or up")
check(ns.ready == true and #printed == 0, "ready, nothing printed")

check(ns.Applies({ npcID = 10 }) == true, "a creature with abilities is taken")
check(ns.Applies({ npcID = 20 }) == false, "a creature with none is left alone")
check(ns.Applies({ itemID = 7 }) == false, "a row with no creature is left alone")
check(ns.Applies({ npcID = 0 }) == false, "a zero id is no creature")

local lines = Lines(ns, 10)
check(#lines == 6, "a blank, the header, three ability lines and the hint; got " .. #lines)
check(lines[2] == "Abilities, from Classic Bestiary", "the header names the source")
check(lines[3]:find("Infected Bite", 1, true) ~= nil and lines[3]:find("|T1100:14:14", 1, true) ~= nil,
    "an ability line carries its icon and name")
check(lines[6] == "Hold Ctrl for details", "the hint names Classic Bestiary's details key")
check(not has(lines, "Infects the target."), "no texts without the key")

lines = Lines(ns, 30)
check(#lines == 2 + 8 + 1 + 1, "eight lines, how many more, the hint")
check(lines[11] == "and 4 more", "the count of the rest")
check(#Lines(ns, 20) == 0, "nothing for a creature with no abilities")

-- Ctrl held: every ability with its text and the spells it sets off.
keys.ctrl = true
lines = Lines(ns, 10)
check(lines[4] == "    Infects the target.", "an ability's text under it")
check(has(lines, "Hurls a bolt of shadow.") and has(lines, "Shadow Vulnerability")
    and has(lines, "        Shadow damage taken increased."), "the spell it sets off, with its text")
check(has(lines, "    Melee attack power reduced."), "a spell of the same name lends its text")
local curses = 0
for _, line in ipairs(lines) do if line:find("Curse of Weakness", 1, true) then curses = curses + 1 end end
check(curses == 1, "and is not listed twice")
check(not has(lines, "Hold Ctrl"), "no hint while held")
lines = Lines(ns, 30)
check(#lines == 2 + 12 and not has(lines, "more"), "every ability while held, past the line count")
keys.ctrl = false

-- Classic Bestiary's own options: another key, always, never, no reminder.
ClassicBestiaryCfg.expansion = "shift"
check(has(Lines(ns, 10), "Hold Shift for details"), "its Shift is ours")
keys.ctrl = true
check(not has(Lines(ns, 10), "Infects the target."), "Ctrl does nothing then")
keys.ctrl, keys.shift = false, true
check(has(Lines(ns, 10), "Infects the target."), "Shift shows the details")
keys.shift = false
ClassicBestiaryCfg.expansion = "always"
check(has(Lines(ns, 10), "Infects the target."), "always: details with no key")
ClassicBestiaryCfg.expansion = "never"
lines = Lines(ns, 10)
check(#lines == 5 and not has(lines, "Hold"), "never: no details, no hint")
ClassicBestiaryCfg.expansion, ClassicBestiaryCfg.reminder = nil, false
check(#Lines(ns, 10) == 5, "its reminder off: no hint")
ClassicBestiaryCfg.reminder = nil

-- A spell not loaded yet: asked for once, the tooltip drawn again on arrival.
abilities[40] = { 300 }
cached[300] = false
texts[300] = nil
keys.ctrl = true
Lines(ns, 40)
Lines(ns, 40)
check(#loads == 1 and loads[1].id == 300, "asked for once")
loads[1].fn()
loads[1].fn()
check(#timers == 1, "one redraw for its arrival")
timers[1]()
check(redraws == 1, "the hovered row's tooltip drawn again")
keys.ctrl = false

-- The settings page: a switch and the line count, read and written in EasyFind's saved data.
local kit = Kit()
ns.Settings({}, kit)
local box, choice = kit.made[2], kit.made[3]
check(box and box.kind == "checkbox" and choice and choice.kind == "choice", "a switch and a choice under the title")
check(box.get() == true and choice.get() == 8, "on, eight lines, by default")
box.set(false)
check(ns.Applies({ npcID = 10 }) == false and EasyFind.db.classicBestiary.off == true, "switched off, no row is taken")
box.set(true)
check(ns.Applies({ npcID = 10 }) == true and EasyFind.db.classicBestiary.off == nil, "switched on again")
choice.set(4)
lines = Lines(ns, 30)
check(#lines == 2 + 4 + 1 + 1 and lines[7] == "and 8 more", "four lines listed")
choice.set(0)
check(#Lines(ns, 30) == 2 + 12 + 1, "all lines listed")

io.write(failures == 0 and "== bestiary tests: all passed ==\n" or ("== bestiary tests: " .. failures .. " failed ==\n"))
os.exit(failures == 0 and 0 or 1)
