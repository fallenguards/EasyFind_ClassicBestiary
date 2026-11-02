-- Bestiary.lua against a stand-in Classic Bestiary and EasyFind API: what
-- registers, which rows the decorator takes, the tooltip's lines, and the
-- settings page's switches. Run: lua tests/test_bestiary.lua
local ROOT = (arg and arg[0] or ""):match("^(.-)tests[/\\]") or "./"

-- The Bestiary's API: creature 10 casts three spells, 20 nothing, 30 twelve.
local abilities = { [10] = { 100, 101, 102 }, [20] = {}, [30] = {} }
for i = 1, 12 do abilities[30][i] = 200 + i end
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
}

-- The client: spell names and icons, an addon list, a frame with one event.
local names = { [100] = "Infected Bite", [101] = "Shadow Bolt", [102] = "Curse of Weakness" }
for i = 1, 12 do names[200 + i] = "Spell " .. i end
C_Spell = { GetSpellName = function(id) return names[id] end, GetSpellTexture = function(id) return 1000 + id end }
C_AddOns = { IsAddOnLoaded = function(name) return name == "ClassicBestiary" end }
local handlers = {}
function CreateFrame()
    return { RegisterEvent = function() end, UnregisterEvent = function() end,
             SetScript = function(_, _, fn) handlers[#handlers + 1] = fn end }
end
local printed = {}
print = function(...) printed[#printed + 1] = table.concat({ ... }, " ") end

-- EasyFind's API and saved data: what the extension registers lands here.
local registered = {}
EasyFind = { db = {}, API = {
    VERSION = 1,
    RegisterExtension = function(def) registered.extension = def return true end,
    RegisterRowDecorator = function(def) registered.decorator = def return true end,
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

local ns = LoadAddon()
check(registered.extension and registered.extension.id == "classicbestiary", "the extension registers")
check(registered.extension.icon:find("bestiary", 1, true) ~= nil, "with its own glyph")
check(registered.extension.settings == ns.Settings, "its tile opens its settings page")
check(registered.decorator and registered.decorator.tooltip == ns.Tooltip, "a tooltip decorator registers at login")
check(ns.ready == true and #printed == 0, "ready, nothing printed")

check(ns.Applies({ npcID = 10 }) == true, "a creature with abilities is taken")
check(ns.Applies({ npcID = 20 }) == false, "a creature with none is left alone")
check(ns.Applies({ itemID = 7 }) == false, "a row with no creature is left alone")
check(ns.Applies({ npcID = 0 }) == false, "a zero id is no creature")

local tip = Tip()
ns.Tooltip({ npcID = 10 }, nil, tip)
check(#tip.lines == 5, "a blank, the header and three ability lines; got " .. #tip.lines)
check(tip.lines[2] == "Abilities, from Classic Bestiary", "the header names the source")
check(tip.lines[3]:find("Infected Bite", 1, true) ~= nil and tip.lines[3]:find("|T1100:14:14", 1, true) ~= nil,
    "an ability line carries its icon and name")

tip = Tip()
ns.Tooltip({ npcID = 30 }, nil, tip)
check(#tip.lines == 2 + 8 + 1, "eight lines, then how many more")
check(tip.lines[#tip.lines] == "and 4 more", "the count of the rest")

tip = Tip()
ns.Tooltip({ npcID = 20 }, nil, tip)
check(#tip.lines == 0, "nothing for a creature with no abilities")

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
tip = Tip()
ns.Tooltip({ npcID = 30 }, nil, tip)
check(#tip.lines == 2 + 4 + 1 and tip.lines[#tip.lines] == "and 8 more", "four lines listed")
choice.set(0)
tip = Tip()
ns.Tooltip({ npcID = 30 }, nil, tip)
check(#tip.lines == 2 + 12, "all lines listed")

io.write(failures == 0 and "== bestiary tests: all passed ==\n" or ("== bestiary tests: " .. failures .. " failed ==\n"))
os.exit(failures == 0 and 0 or 1)
