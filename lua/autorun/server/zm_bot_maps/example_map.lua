-- This is an example file, not an actual map.

-------------------------------------
-- mapSettings Table layout
-------------------------------------
-- Table
    -- First Element String: Option to edit
    -- Second Element Var: New value for option

-- These setting names are the variables in the options table in the zm_bot.lua file.
-- Unlike most of below, these cannot be nil. They have to be defined with a var if added.
-- Such as a String, Boolean, Float, Int, Table, etc.. Depending on what the setting needs.
-------------------------------------

local ents = ents.FindByClass("info_manipulate") -- For below example, gets all traps.

local mapSettings = {
    --Examples
    {"MinTrapRange", 10000}, -- Changes the minimum trap range on the map to 10000 Units
    {"MaxTrapRange", 10001},
    {"MinTrapChance", 0.01},
    {"MaxTrapChance", 0.4},
    {"ZombiesPerPlayer", 8}
    {"LastTrapUsed", ents[math.random(#ents)]} -- Example of putting a trap entity into LastTrapUsed.
}

-------------------------------------
-- mapTrapSettings Table layout
-------------------------------------
-- trapName String: What's the trap, can be nil
-- creationID Integer: Map creationID of the trap, can't be nil
-- usageChance Float: Chance the trap is used, can be nil
-- usageRadius Integer: The radius of the trap, can be nil
-- positions Table: Position for the trap (One vector), trigger box (Two vectors), nil means default position, can be nil
-- lineOfSight Boolean: If player needs to be in view of the trap, can be nil

-- AI will use his generated default for the trap given the settings if given nil
-------------------------------------

local mapTrapSettings = {
    -- Examples
    {
        trapName    = "Exploding Barrel",
        creationID  = 2015,
        usageChance = nil,
        usageRadius = nil,
        positions   = {Vector(-2290, 2322, -231)}, -- Sphere
        lineOfSight = true
    },
    {
        trapName    = "Falling Rock",
        creationID  = 2015,
        usageChance = 0.3, -- 0.3 being 3%. 1 being 100%. A negative number meaning will never be used
        usageRadius = 256, -- In Units
        positions   = nil,
        lineOfSight = false
    },
    {
        trapName    = "Long ramp which barrels fall down",
        creationID  = 2015,
        usageChance = nil,
        usageRadius = nil, -- un-used for trigger box
        positions   = {Vector(-2290, 2322, -231), Vector(-234, 543, 300)}, -- Trigger box which covers the ramp, for example.
        lineOfSight = false -- Better to be false if using trigger box
    },
}

-------------------------------------
-- mapExplosionSettings Table layout
-------------------------------------
-- explosionName String: What's the explosion, can be nil
-- useExplosionChance Float: Chance the explosion is used, can be nil
-- explosionUsageRadius Integer: the radius of the explosions checking range, can be nil
-- position Vector: Position for the explosion, can't be nil
-- lineOfSight Boolean: If player needs to be in view of the explosion location, can't be nil

-- AI will generate random given current settings if given is nil
-------------------------------------

local mapExplosionSettings = {
    -- Example
    {
        explosionName = "Inside the small building at all the boxes",
        useExplosionChance = 0.3,
        explosionUsageRadius = 16,
        position = Vector(345, -3453, -245),
        lineOfSight = true
    },
    {
        explosionName = "Inside the small building at all the boxes",
        useExplosionChance = nil,
        explosionUsageRadius = nil,
        position = Vector(345, -3453, -245),
        lineOfSight = true
    }
}

-- Should return mapSettings and mapTrapSettings then mapExplosionSettings. If nothing to return should just put a nil in its place.
return mapSettings, mapTrapSettings, mapExplosionSettings

-- Another example if the map does not change mapSetting or mapTrapSettings
return nil, nil, mapExplosionSettings