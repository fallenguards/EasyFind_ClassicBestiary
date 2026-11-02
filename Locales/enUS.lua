local _, ns = ...

-- Every string the player sees. Other locales override keys in files of
-- their own; a missing key falls back to this one.
local L = setmetatable({}, { __index = function(t, k) return k end })
ns.L = L

L["EXT_NAME"] = "Classic Bestiary"
L["EXT_DESC"] = "Classic Bestiary's creature abilities on EasyFind's results: hover an NPC or boss row."

L["TT_HEADER"] = "Abilities, from Classic Bestiary"
L["TT_MORE_FMT"] = "and %d more"
L["NOT_READY_EASYFIND"] = "EasyFind needs an update before Classic Bestiary's abilities can show on its rows."
L["NOT_READY_BESTIARY"] = "Classic Bestiary is newer than this extension knows; update EasyFind [Classic Bestiary]."
