std = "lua51"
max_line_length = false

ignore = {
    "431",  -- shadowing upvalue (self in nested callbacks is standard WoW pattern)
    "432",  -- shadowing upvalue argument
}

globals = {
    "EasyFind",
}

read_globals = {
    -- Classic Bestiary's API, read at runtime
    "ClassicBestiary",
    -- WoW API
    "C_AddOns", "IsAddOnLoaded", "CreateFrame", "C_Spell", "GetSpellInfo", "GetSpellTexture",
    "GetSpellDescription", "Spell", "C_Timer", "IsControlKeyDown", "IsShiftKeyDown", "IsAltKeyDown",
}

unused_args = false
self = false

-- The tests set up stand-in globals for Classic Bestiary and the game.
files["tests"] = { std = "max", ignore = { "1" } }
files["tools/tests"] = { std = "max", ignore = { "1" } }
