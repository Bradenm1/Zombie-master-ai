-- Author: Bradenm1
-- Repo: https://github.com/Bradenm1/Zombie_Master_Bot

if (SERVER) then

include("botnames.lua")

-- Saving while playing and editing the bot will break it

-- Constants
local GAMEMODE = "zombiemaster"
local HUMANTEAM = 1
local ZOMBIEMASTERTEAM = 2
local SPECTATORTEAM = 3
local DAMAGEZOMBIEMULTIPLIER = 1.25

-- Vars
local speedDelay, spawnDelay, commandDelay, killZombieDelay, spawnRangeDelay, explosionDelay = 0, 0, 0, 0, 0, 0 -- Delays
local zmBot = nil -- Where the player bot is stored, this is more effiencent since don't need to loop though all bots

-- Bot Options
-- Chance: 0.0 never use 1.0 always use
-- Radius/Range: Units
-- Theses are the default stats
local options = {
	MaxZombies 			= 60, -- Max zombies this changes depending on the players
	SpawnRadius			= 3000, -- Max spawn distance
	DeleteRadius 		= 3000, -- Min distance to delete zombies
	ZombiesPerPlayer	= 14, -- Zombies per player on the server
	MinTrapRange		= 92, -- Min range to use trap around players
	MaxTrapRange 		= 224, -- Max range to use trap around players
	TrapUsageRadius		= 128, -- Max distance to use a trap when a player is near
	UseTrapChance  		= 0.2, -- Use trap chance
	MinTrapChance  		= -0.02, -- Min trap chance
	MaxTrapChance  		= 1, -- Max trap chance
	SpawnZombieChance	= 0.5, -- Zombie spawn Chance
	MaxZombieTypeChance	= 10, -- Type of zombie to spawn chance
	MinSpawnChance		= 0.03, -- Min zombie spawn chance
	MaxSpawnChance		= 1, -- Max zombie spawn chance
	IncressSpawnRange	= 300, -- How much it should incress the range by
	UseExplosionChance	= 0.1, -- Min explosion chance
	MinExplosionChance	= -0.01, -- Max explosion chance
	MaxExplosionChance	= 0.03, -- Use explosion chance
	ExplosionSearchRange= 32, -- Range from player it searches
	ExplosionUseAmount	= 5, -- Number of Entites needed in range
	BotSpeed			= 1, -- Delay in seconds, speed of the bot as a whole
	ZombieSpawnDelay 	= 3, -- Delay in seconds, zombie spawn delay
	CommandDelay 		= 1, -- Delay in seconds, command zombie delay
	KillZombieDelay		= 1, -- Delay in seconds, killing zombies
	SpawnRangeDelay		= 10, -- Delay in seconds, incressing range if no zombies
	ExplosionDelay		= 10, -- Delay in seconds
	Playing				= true, -- If the bot is currently playing
	SpawnForcing		= true, -- Forces players to spawn on game start
								 -- True means it changes on the fly each time a trap is used
								 -- False means it does not and all traps have set chances and ranges from the start of the round
	Debug 				= false, -- Used for basic debugging
	SetUp 				= true, -- Setup for the bot
	LastSpawned			= nil, -- Last spawner used
	LastTrapUsed		= nil, -- Last trap used
	LastZombieCommanded = nil, -- Last zombie commanded
	View				= nil, -- Where the bot currently is
	Traps				= {} -- Used to stored the traps at round starts if dynamic is false
}

----------------------------------------------------
-- get_amount_zm_bots()
-- Returns amount of Zombie Master bots
-- @return amount Integer: Amount of bots
----------------------------------------------------
local function get_amount_zm_bots()
	local amount = 0
	for _, bot in pairs(player.GetBots()) do 
		if (bot.IsZMBot) then amount = amount + 1 end
	end
	return amount
end

----------------------------------------------------
-- get_last_zombie_commanded()
-- Returns last zombie the AI commanded
-- @return options.LastZombieUsed Entity: Zombie
----------------------------------------------------
local function get_last_zombie_commanded()
	return options.LastZombieCommanded
end

----------------------------------------------------
-- get_zombie_amount()
-- Gets amount of zombies currently on the map
-- @return amount Integer: amount of zombies
----------------------------------------------------
local function get_zombie_population()
	return gamemode.Call("GetCurZombiePop")
end

----------------------------------------------------
-- get_max_zombies()
-- Gets the max zombies
-- @return maxZombies Integer: max zombies
----------------------------------------------------
local function get_max_zombies()
	local maxZombies = #team.GetPlayers(HUMANTEAM) * options.ZombiesPerPlayer
	return maxZombies
end

----------------------------------------------------
-- get_max_zombies()
-- Gets the max zombies
-- @return amount Integer: number of zombie types
----------------------------------------------------
local function get_zombie_type_amount()
	local amount = table.Count(gamemode.Call("GetZombieTable", false))
	return amount
end

----------------------------------------------------
-- get_zombie_chance()
-- Returns the chance of picking a zombie
-- @return chance Integer: chance
----------------------------------------------------
local function get_zombie_chance()
	local chance = math.random(0, options.MaxZombieTypeChance) % get_zombie_type_amount()
	return chance
end

----------------------------------------------------
-- get_chance_explosion()
-- Returns a random decimnal number
-- @return chance Float: chance
----------------------------------------------------
local function get_chance_explosion()
	local chance = math.Rand(options.MinExplosionChance, options.MaxExplosionChance) -- Negative means trap won't get used
	return chance
end

----------------------------------------------------
-- get_chance_trap()
-- Returns a random decimnal number
-- @return chance Float: chance
----------------------------------------------------
local function get_chance_trap()
	local chance = math.Rand(options.MinTrapChance, options.MaxTrapChance) -- Negative means trap won't get used
	return chance
end

----------------------------------------------------
-- get_chance_spawn()
-- Returns a random decimnal number
-- @return chance Float: chance
----------------------------------------------------
local function get_chance_spawn()
	local chance = math.Rand(options.MinSpawnChance, options.MaxSpawnChance) -- 0.03 would be 3% and 1 would be 100%
	return chance
end

----------------------------------------------------
-- get_trap_usage_radius()
-- Returns a random Integer number
-- @return radius Integer: returns an amount
----------------------------------------------------
local function get_trap_usage_radius()
	local radius = math.random(options.MinTrapRange, options.MaxTrapRange) -- In units
	return radius
end

----------------------------------------------------
-- get_last_trap_used()
-- Returns last trap the AI used
-- @return options.LastTrapUsed Entity: Trap
----------------------------------------------------
local function get_last_trap_used()
	return options.LastTrapUsed
end

----------------------------------------------------
-- debug_show_stats()
-- Shows stats of bot
----------------------------------------------------
local function debug_show_stats()
	zmBot:Say("Use Trap Chance: " .. options.UseTrapChance)
	zmBot:Say("Spawn Zombie Chance: " .. options.SpawnZombieChance)
	zmBot:Say("Trap Usage Radius: " .. options.TrapUsageRadius)
end

----------------------------------------------------
-- check_zombie_class()
-- Check if given ent is a zombie
----------------------------------------------------
local function check_zombie_class(ent)
	for _, zb in pairs(gamemode.Call("GetZombieTable", false)) do
		if (ent:GetClass() == zb.Class) then return true end
	end
	return false
end

----------------------------------------------------
-- get_zombie_too_far()
-- Checks for zombies too far away from players and deletes them
-- @return zombies Table: zombies too far away
----------------------------------------------------
local function get_zombie_too_far()
	local zombies = {}
	local index = 0
	for _, ply in pairs(team.GetPlayers(HUMANTEAM)) do -- Loop through survivors
		for __, zb in pairs(ents.FindByClass("npc_*")) do -- Loop through all zombies
			if (check_zombie_class(zb)) then
				if (ply:GetPos():Distance(zb:GetPos()) >= options.DeleteRadius) then -- Get distance between zombie and survivor
					zombies[index] = zb -- Adds zombie to list if not near player
				else zombies[index] = nil end -- Removes zombie from the list if near player
				index = index + 1 -- Increment index
			end
		end
		index = 0
	end
	return zombies
end

----------------------------------------------------
-- kill_zombie()
-- Kills a given zombie
-- @param zb Entity: Zombie to be deleted
----------------------------------------------------
local function kill_zombie(zb)
	if (options.Debug) then zmBot:Say("Zombie Has been killed and removed, to far away from any players.") end
	local dmginfo = DamageInfo()
	dmginfo:SetDamage(zb:Health() * DAMAGEZOMBIEMULTIPLIER)
	zb:TakeDamageInfo(dmginfo) 
	zb:Remove()
end

----------------------------------------------------
-- kill_all_zombies()
-- Kills all zombies within a table
-- @param tb Table: table containting zombies
----------------------------------------------------
local function kill_all_zombies(tb)
	for _, zb in pairs(tb) do
		if (zb) then kill_zombie(zb) end
	end
end

----------------------------------------------------
-- move_zombies_to_players()
-- Moves random zombie to random player
----------------------------------------------------
local function move_zombie_to_player()
	local player = table.Random(team.GetPlayers(HUMANTEAM)) -- Get Random survivor
	local zb = table.Random(ents.FindByClass("npc_*")) -- Get random zombie
	if ((IsValid(player)) && (IsValid(zb)) && (check_zombie_class(zb))) then zb:ForceGo(player:GetPos()) end
	options.LastZombieCommanded = zb
end

----------------------------------------------------	
-- create_zm_view()
-- Creates the box for the current pos of the AI
----------------------------------------------------
function create_zm_view()
	options.View = ents.Create("prop_thumper")
	if (!IsValid(options.View)) then return end
	options.View:SetModel( "models/props_wasteland/controlroom_filecabinet001a.mdl" )
	options.View:SetMaterial( "models/XQM/LightLinesRed_tool", true )
	options.View:SetColor(Color(255, 0, 0))
	options.View:SetPos(Vector(0, 0, 0))
	options.View:StopMotionController()
	options.View:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
	options.View:Spawn()
end

----------------------------------------------------	
-- get_creationid_within_range()
-- Displays creationID for a trap close to a player
----------------------------------------------------
local function get_creationid_within_range()
	for _, ent in pairs(ents.FindByClass("info_manipulate")) do  -- Gets all traps
		for ___, ply in pairs(ents.FindInSphere(ent:GetPos(), 96)) do -- Checks if any players within given radius of the trap
			if (ply:IsPlayer()) then 
				print("CreationID: " .. ent:MapCreationID())
			end
		end
	end
end


----------------------------------------------------
-- pick_zombie()
-- Picks a random zombie
-- @return zb String: The zombie to use as class
----------------------------------------------------
local function pick_zombie()
	local tb = gamemode.Call("GetZombieTable", false)
	local zb = "npc_zombie"
	for _, zm in pairs(tb) do -- Finds zombie
		if (get_zombie_chance() == 0) then zb = zm.Class end -- Checks if this is the zombie to use
	end
	return zb
end

----------------------------------------------------
-- spawn_zombie()
-- Spawns a zombie
-- @param ent Entity: Spawn to spawn zombie at
----------------------------------------------------
local function spawn_zombie(ent)
	if (options.SpawnZombieChance < math.Rand(0, 1)) then return nil end
	local zb = pick_zombie()
	-- Attempt to spawn another zombie if failed
	--[[local allowed = true
	local attempts = 0
	while (allowed) do
		if (attempts > 5) then 
			if (options.Debug) then zmBot:Say("Attempt to spawn zombie failed... Query: " .. #ent.query) end
			return nil 
		end
		local data = gamemode.Call("GetZombieData", zb)
		if ((data) && (#ent.query < 18)) then
			local zombieFlags = ent:GetZombieFlags() or 0
			allowed = gamemode.Call("CanSpawnZombie", data.Flag or 0, zombieFlags)
			if (!allowed) then zb = pick_zombie() end
			attempts = attempts + 1
		end
	end]]
	ent:AddQuery(zmBot, zb, 1)
	options.LastSpawned = ent
	if (options.Debug) then zmBot:Say("Attempted to spawn: " .. zb) end
end

----------------------------------------------------
-- check_for_spawner()
-- Finds zombies spawners and spawns a zombie
-- @return entToUse Entity: cloeset spawner
----------------------------------------------------
local function check_for_closest_spawner()
	if (get_zombie_population() > options.MaxZombies) then return nil end
	local zombieSpawns = ents.FindByClass("info_zombiespawn")
	if (#zombieSpawns == 0) then return nil end -- Checks if there's any spawns
	local player = table.Random(team.GetPlayers(HUMANTEAM)) -- Picks a random player from humanteam
	local entToUse = nil -- Default to nil
	for __, spawn in RandomPairs(zombieSpawns) do -- Find cloest spawn point
		if ((IsValid(spawn)) && (spawn:GetActive())) then
			if (entToUse) then -- If it's not the first zombie spawner
				local newDis = spawn:GetPos():Distance(player:GetPos()) -- Get Distance of new spawner
				local oldDis = entToUse:GetPos():Distance(player:GetPos()) -- Get Distance of stored spawner
				if (oldDis > newDis) then entToUse = spawn end -- Check which one is closer
			else entToUse = spawn end -- Set First Spawner in the table to check
		end
	end
	if (!entToUse) then return nil end
	local dis = entToUse:GetPos():Distance(player:GetPos()) -- Get distance of closest spawner to player
	if (dis > options.SpawnRadius) then return nil end -- Checks if spawn is within distance
	return entToUse -- Return the closest spawn
end

----------------------------------------------------	
-- set_map_settings()
-- Checks for a certain map and adds custom settings
----------------------------------------------------
-- Will be move to another file in the future
local function set_map_settings()
	local map = game.GetMap()
	if (map == "zm_deathrun_a7") then -- Apply custom settings for map zm_deathrun_a7
		options.MinTrapRange = 10000 -- Units
		options.MaxTrapRange = 10001 -- Units
		options.MinTrapChance = 0.01 -- Percent
		options.MaxTrapChance = 0.4 -- Percent
	end
end

----------------------------------------------------	
-- set_trap_settings()
-- Set custom stats for a certain trap
-- @param arg1 Integer: CreationID of the entity
-- @param arg2 Float: Trap usage chance
-- @param arg3 Integer: Trap usage radius
-- @param arg4 Table: Vector(s) position for trap or position of trigger box
-- @param arg5 Boolean: If a player needs to be in line of sight
-- @return Boolean: If CreationID exists and settings were applied
----------------------------------------------------
local function set_trap_settings(...) 
	local arguments = {...} -- Get passed in arguments as table
	for key, trap in pairs(options.Traps) do 
		if (trap.Trap == arguments[1] ) then
			-- HACK
			table.remove( options.Traps, key ) -- Has to be removed or it duplicates, cannot just assign to that key in the table.
											   -- Does not seem to point at orginal, rather a new slot.
			table.insert( options.Traps, { -- Add it again
				Trap = arguments[1] or trap.Trap,
				UseTrapChance = arguments[2] or trap.UseTrapChance,
				TrapUsageRadius = arguments[3] or trap.TrapUsageRadius,
				Position = arguments[4] or trap.Position,
				HasToBeVisible = arguments[5] -- Boolean 
			})
			return true -- Setting was a success
		end
	end
	print("Error setting creationID: " .. arguments[1] .. " does not exists...")
	return false -- Setting as a failure
end

----------------------------------------------------	
-- set_map_trap_settings()
-- Check for a certain map and sets custom traps
----------------------------------------------------
-- Will be move to another file in the future
local function set_map_trap_settings()
	local map = game.GetMap()
	if (map == "zm_asdf_b5") then -- Apply custom settings for map zm_deathrun_a7
		set_trap_settings(1255, nil, nil, {Vector(-1281, -1952, -948)}, true) -- Red block that falls with hole in center
		local tp = {Vector(-734, -1215, -911)}
		set_trap_settings(2437, nil, nil, tp, true) -- tp
		set_trap_settings(2220, nil, nil, tp, true) -- tp
		set_trap_settings(2215, nil, nil, tp, true) -- tp
		local path = {Vector(731, -2085, -834)}
		set_trap_settings(1264, nil, nil, path, true) -- path
		set_trap_settings(1265, nil, nil, path, true) -- path
		set_trap_settings(1266, nil, nil, path, true) -- path
		local laser = {Vector(22, -189, -663)}
		set_trap_settings(2379, nil, nil, laser, true) -- laser
		set_trap_settings(2393, nil, nil, laser, true) -- laser
		set_trap_settings(2393, nil, nil, laser, true) -- laser
		set_trap_settings(1275, nil, nil, {Vector(605, -1462, -175)}, true) -- red wall
	elseif (map == "zm_gasdump_b4") then
		set_trap_settings(2452, 0.02, 2096, nil, false) -- Tornado
	elseif (map == "zm_backwoods_b4") then
		-- Trigger is in not the best spot for these trap doors
		set_trap_settings(2015, nil, nil, {Vector(-2290, 2322, -231)}, true) -- First trap door
		set_trap_settings(2016, nil, nil, {Vector(-3057, 2326, -227)}, true) -- Second trap door
		set_trap_settings(2350, nil, nil, {Vector(-5731, 7199, -229)}, true) -- Third trap door
		set_trap_settings(2367, nil, nil, {Vector(-7438, 7187, -229)}, true) -- Fourth trap door
		set_trap_settings(1260, nil, nil, {Vector(-4352, 7494, -23)}, false) -- Tall Building
	elseif (map == "zm_basin_b3fix") then
		set_trap_settings(2656, nil, nil, {Vector(-3599, 22, 303)}, true) -- Kill AFKs
		set_trap_settings(2353, nil, nil, {Vector(-722, -2255, -167)}, false) -- First gate
		set_trap_settings(2689, nil, nil, {Vector(1794, -2143, 126)}, true) -- Hanging timber outside hanger door
		set_trap_settings(2342, nil, nil, {Vector(1768, -3061, 146)}, true) -- Drop building overhanging roof
		set_trap_settings(2367, nil, nil, {Vector(2861, -2513, 142)}, false) -- Second Gate
		set_trap_settings(2710, nil, nil, {Vector(3576, 1920, 173)}, true) -- Motor Bomb
		set_trap_settings(2585, nil, nil, {Vector(2096, 3466, 151)}, true) -- Trailer cannon explosion
		set_trap_settings(2608, nil, nil, {Vector(-799, 4488, 105)}, true) -- Drop Trailer over railing
		set_trap_settings(2518, nil, nil, {Vector(-2546, 2752, 105)}, false) -- Open building near boat
	elseif (map == "zm_diamondshoals_a2") then
		set_trap_settings(2154, nil, nil, {Vector(608, 3188, -1007)}, false) -- FLoating explosive barrel boat
		set_trap_settings(2163, nil, nil, {Vector(1418, 5481, -872)}, true) -- Crab Sign
	elseif (map == "zm_bluevelvet_rc1") then
		set_trap_settings(2149, nil, nil, {Vector(-2033, 1913, -152)}, false) -- Auto Opening door
		set_trap_settings(2187, nil, nil, nil, false) -- Door
		set_trap_settings(1825, nil, nil, nil, false) -- Same door
		set_trap_settings(3373, nil, nil, {Vector(-6015, 847, -553)}, false) -- Spawn immolator near door to cut at trains
		set_trap_settings(3396, nil, nil, {Vector(-3227, 983, -542)}, false) -- Spawn banshees opposite side
	elseif (map == "zm_countrytrain_b4") then
		set_trap_settings(2997, nil, nil, {Vector(-667, 1517, 63)}, false) -- Dumb rock
		set_trap_settings(3244, nil, nil, {Vector(907, -503, 46)}, false) -- Second falling gate
		set_trap_settings(3025, nil, nil, {Vector(27, 2492, 46)}, false) -- Throw rocks onto train tracks
		set_trap_settings(3248, nil, nil, {Vector(2805, 1149, 25)}, false) -- First falling gate
		set_trap_settings(1671, nil, nil, {Vector(2849, -597, 37)}, true) -- Send banshee into shed roof window
		set_trap_settings(3288, nil, nil, {Vector(1512, 577, 32)}, false) -- Spawn two hulks
		set_trap_settings(2498, nil, nil, {Vector(2126, -75, 51)}, false) -- Spawn immolator
		set_trap_settings(3208, nil, nil, {Vector(-1879, 2111, 50)}, false) -- Spawn banshee onto of spawn building
		set_trap_settings(3008, nil, nil, {Vector(598, 37, 114)}, false) -- Falling rocks at second gate
		set_trap_settings(2008, nil, nil, {Vector(-563, -1011, 51)}, false) -- Raise 2 immolators at gas station
		set_trap_settings(2995, nil, nil, {Vector(-1146, 368, 59)}, false) -- Falling rocks on path
	elseif (map == "zm_forestroad") then
		set_trap_settings(2047, nil, nil, {Vector(2041, 1275, 267)}, true) -- Zap shed
		set_trap_settings(2254, nil, nil, {Vector(4367, -1463, 86)}, false) -- Oil fire
		set_trap_settings(2049, nil, nil, {Vector(4742, -2415, 64)}, true) -- Drop giant rock
	elseif (map == "zm_4dtetris_new") then
		local slots = {}
		local traps = {	{1237, 1246, 1320, 1338, 1354, 1370, 1388, 1436}, 
						{1238, 1247, 1321, 1339, 1355, 1371, 1389, 1437},
						{1239, 1248, 1322, 1340, 1356, 1372, 1390, 1438},
						{1240, 1249, 1323, 1341, 1357, 1373, 1391, 1439},
						{1241, 1250, 1324, 1342, 1358, 1374, 1392, 1440, 1404, 1456, 1881},
						{1242, 1251, 1325, 1343, 1359, 1375, 1393, 1441},
						{1243, 1252, 1326, 1344, 1358, 1376, 1394, 1442},
						{1244, 1253, 1327, 1345, 1359, 1377, 1395, 1443},
						{1245, 1254, 1328, 1345, 1360, 1378, 1395, 1444}
					}
		local firstCal, secondCal = -1024, -557
		-- Create triggers
		for i=1, #traps do -- Each slot
			slots[i] = {Vector(836, firstCal, -3300), Vector(1066, secondCal, 3013)} -- Box
			firstCal = firstCal + 200 -- Size of trigger
			secondCal = secondCal + 250 -- Size of trigger
		end
		-- Put which trap belongs on what trigger
		for i=1, #slots do -- Each slot
			for o=1, #traps[i] do -- Each trap in the slot
				set_trap_settings(traps[i][o], nil, nil, slots[i], true) -- Set the trap
			end 
		end
	end
end

----------------------------------------------------
-- create_explosion()
-- Causes a explosion forces props away
-- @param location Vector: Location where explosion will appear
----------------------------------------------------
local function create_explosion(location)
	local ent = ents.Create("env_delayed_physexplosion")
	if IsValid(ent) then
		ent:Spawn()
		ent:SetPos(location)
		ent:Activate()
		ent:DelayedExplode(ZM_PHYSEXP_DELAY)
	end
end

----------------------------------------------------
-- activate_trap()
-- Triggers a trap
-- @param arg1 Entity: The trap to be activated
-- @param arg2 Float: Chance for the trap to be used -- Only passed in if dynamic is false
-- @param arg3 Integer: Used for removing of trap from list
----------------------------------------------------
local function activate_trap(ent)
	ent:Trigger(zmBot)
	zmBot:TakeZMPoints(ent:GetCost())
	options.LastTrapUsed = ent
	if (options.Debug) then zmBot:Say("Trap activated.") end -- Debugging
end

----------------------------------------------------
-- get_trap_settings()
-- Gets the trap settings for the given trap
-- @param arg1 Entity: The trap to be checked
-- @return trapSettings Table: Table containing the settings
----------------------------------------------------
local function get_trap_settings(ent)
	for __, trapSettings in pairs(options.Traps) do -- Checks both keys to find the trap in the traps table that's being checked
		if (ent:MapCreationID() == trapSettings.Trap) then -- If it's the same trap being checked as the one in the traps table
			return trapSettings -- Returns the settings
		end
	end
end

----------------------------------------------------
-- check_for_traps()
-- Checks for traps within radius of players
-- @return ent Entity: Trap which has been found
----------------------------------------------------
local function check_for_traps()
	for _, ent in RandomPairs(ents.FindByClass("info_manipulate")) do  -- Gets all traps
		if (IsValid(ent)) then -- Check if trap is vaild and not used
			local sphereSearch, positions, searchType = true, nil, nil
			local settings = get_trap_settings(ent) -- Get trap settings
			if (table.Count(settings.Position) > 1) then 
				sphereSearch = false 
				positions = settings.Position -- Gets vectors as a table
			else 
				ent:SetPos(settings.Position[1]) -- Gets the one vector
			end
			if (sphereSearch) then searchType = ents.FindInSphere(ent:GetPos(), settings.TrapUsageRadius) else searchType = ents.FindInBox(positions[1], positions[2]) end
			for ___, ply in RandomPairs(searchType) do -- Checks if any players within given radius of the trap
				if ((ply:IsPlayer()) && (ent:GetActive())) then -- Check if entity is player 
					if (!ply.IsZMBot) then 
						local canUse = true
						if (settings.HasToBeVisible) then -- If it matters if the trap is visible
							if (!ent:Visible(ply)) then -- is not visible to the trap
								canUse = false
							end 
						end
						if (options.Debug) then zmBot:Say(ply:Nick() .. " Is within a trap at of radius: " .. settings.TrapUsageRadius .. " of chance: " .. settings.UseTrapChance .. " at going off.") end
						if (canUse) then return ent end
					end
				end 
			end
		end
	end
	return nil -- If no traps were found
end

----------------------------------------------------
-- set_up_all_traps()
-- Sets up all the traps from the get go with stats
----------------------------------------------------
local function set_up_all_traps()
	for _, ent in pairs(ents.FindByClass("info_manipulate")) do  -- Gets all traps
		table.insert( options.Traps, {
			Trap = ent:MapCreationID(),
			UseTrapChance = get_chance_trap(),
			TrapUsageRadius = get_trap_usage_radius(),
			Position = {ent:GetPos()}, -- Incase we need to fake it
			HasToBeVisible = true
		})
	end
	if (options.Debug) then PrintTable(options.Traps) end
end

----------------------------------------------------
-- set_zm_settings()
-- Sets up the bots stats
----------------------------------------------------
local function set_zm_settings()
	if (options.SetUp) then -- The setup for the bot 
		-- This section is done once during the round start
		set_map_settings() -- Set if certain map is on
		set_up_all_traps() -- Sets up the traps in the map
		set_map_trap_settings() -- Has to be after
		zmBot:SetZMPoints(10000)
		options.UseExplosionChance = get_chance_explosion()
		options.Debug = false
		options.View = nil
		options.SetUp = false
	else -- Dynamic stats, that can change during the game
		options.MaxZombies = get_max_zombies()
	end
end

----------------------------------------------------
-- using_spawner()
-- Controls the bot using a spawner
----------------------------------------------------
local function using_spawner()
	if (CurTime() < spawnDelay) then return end
	local cloestSpawnPoint = check_for_closest_spawner() -- Check cloest spawn to players
	if (cloestSpawnPoint) then spawn_zombie(cloestSpawnPoint) end -- Spawn zombie
	spawnDelay = CurTime() + options.ZombieSpawnDelay
end

----------------------------------------------------
-- using_explosion()
-- Controls the bot using the explosion
----------------------------------------------------
local function using_explosion()
	if ((CurTime() < explosionDelay) || (options.UseExplosionChance < math.Rand(0, 1))) then return end
	for ___, ply in RandomPairs(team.GetPlayers(HUMANTEAM)) do
		local amount = #ents.FindInSphere(ply:GetPos(), options.ExplosionSearchRange) -- Get all amount of ents within range of player
		if (amount > options.ExplosionUseAmount) then
			create_explosion(ply:GetPos()) -- Create explosion at player
			options.UseExplosionChance = get_chance_explosion()
			explosionDelay = CurTime() + options.ExplosionDelay
		end
	end
end

----------------------------------------------------
-- can_use_trap()
-- Checks for traps within radius of players
-- @param ent Entity: The trap to be checked
-- @return Boolean: If trap can be used
----------------------------------------------------
local function can_use_trap(ent)
	local settings = get_trap_settings(ent)
	if (settings.UseTrapChance < math.Rand(0, 1)) then return false else return true end -- Check chances of using the trap
end

----------------------------------------------------
-- using_trap()
-- Controls the bot using the traps
----------------------------------------------------
local function using_trap()
	local trap = check_for_traps() -- Check if player is near trap
	if (!trap) then return end -- Checks if a trap was found
	local canUse = can_use_trap(trap) -- Checks if the trap can be used
	if (canUse) then activate_trap(trap) end
end

----------------------------------------------------
-- deleting_zombies()
-- Controls the bot deleting zombies
----------------------------------------------------
local function deleting_zombies()
	if (CurTime() < killZombieDelay) then return end
	local zombiesToDelete = get_zombie_too_far() -- Gets zombies too far away from players
	if (zombiesToDelete) then kill_all_zombies(zombiesToDelete) end -- Kills given zombies
	killZombieDelay = CurTime() + options.KillZombieDelay
end

----------------------------------------------------
-- command_zombie()
-- Controls the bot commanding a zombie
----------------------------------------------------
local function command_zombie()
	if (CurTime() < commandDelay) then return end
	move_zombie_to_player() -- Move random zombie towards random player if non in view of that zombie
	commandDelay = CurTime() + options.CommandDelay
end

----------------------------------------------------
-- incress_spawn_range()
-- Controls the bot spawning and deletion range
-- Currently not used
----------------------------------------------------
local function incress_spawn_range()
	if (CurTime() < spawnRangeDelay) then return end
	local zombiePopu = get_zombie_population()
	if (zombiePopu == 0) then 
		local range = options.SpawnRadius + options.IncressSpawnRange
		options.SpawnRadius = range
		options.DeleteRadius = range
		if (options.Debug) then zmBot:Say("No zombies spawned... Incressing range to: " .. range) end
	end
	spawnRangeDelay = CurTime() + options.SpawnRangeDelay
end

----------------------------------------------------
-- zm_brain()
-- Main Entry point of bot
----------------------------------------------------
local function zm_brain()
	if (zmBot:Team() == ZOMBIEMASTERTEAM) then -- Checks if bot is ZM
		-- Code that should run while bot is playing goes here
		-- Functions that will be effected by bot speed go below if realtime go above
		if (CurTime() < speedDelay) then return end
		set_zm_settings() -- Set all the settings
		using_spawner() -- Function which includes functionality using a spawner
		using_trap() -- Function which includes functionality for traps
		using_explosion() -- Function which includes functionality explosions
		deleting_zombies() -- Function which includes functionality for deleting zombies
		command_zombie() -- Function which includes functionality commanding a zombie
		--create_explosion(team.GetPlayers(HUMANTEAM)[1]:GetPos())
		speedDelay = CurTime() + options.BotSpeed -- Bot delay
	else -- Bot is not ZM or round is over, etc..
		if (zmBot:Team() == HUMANTEAM) then if (zmBot:Alive()) then zmBot:Kill() end end -- Checks if bot is a survivor, if so kills himself
		options.SetUp = true
	end
end

----------------------------------------------------
-- create_zm_bot()
-- Spawns the AI bot
----------------------------------------------------
local function create_zm_bot()
	if ((!game.SinglePlayer()) && (#player.GetAll() < game.MaxPlayers())) then
		local bot = player.CreateNextBot(names[math.random(#names)]) -- Create a bot given the name list
		bot.IsZMBot = true -- Set bot as ZM bot
		zmBot = bot -- Assign bot as global for usage
	else print( "Cannot create bot. Do you have free slots or are you in Single Player?" ) end -- This prints to console if the bot cannot spawn
end

----------------------------------------------------	
-- Think
-- Think hook for controlling the bot
----------------------------------------------------
hook.Add( "Think", "Control_Bot", function()
	--get_creationid_within_range()
	if (engine.ActiveGamemode() != GAMEMODE) then -- Checking if gamemode is active
		print("Zombie Master Gamemode not active, disabling ZM AI")
		hook.Remove( "Think", "Control_Bot" ) -- Disables the mod is not active
	else
        if ((options.Playing) && (zmBot) && (#team.GetPlayers(HUMANTEAM) > 0)) then zm_brain() end -- Checks if the bot was created, runs the bot if so
	end
end )

----------------------------------------------------   
-- InitPostClient
-- InitPostClient hook for detecting player join
----------------------------------------------------
hook.Add( "InitPostClient", "Bot_Creation", function()
    if (options.Playing) then
        if (get_amount_zm_bots() == 0) then create_zm_bot() end -- Check if there's already a bot on the server and waits for players to join first
    end
end )

----------------------------------------------------   
-- GetZombieMasterVolunteer
-- GetZombieMasterVolunteer hook for making it where only the bot is choosen
----------------------------------------------------
hook.Add( "GetZombieMasterVolunteer", "Bot_Selection", function()
    if ((options.Playing) && (zmBot)) then
        return zmBot -- Force the zombie master selection to the bot
    end
end )

----------------------------------------------------	
-- CMDs
-- Console Commands for bot
----------------------------------------------------

-- Bot Global Speed Delay
concommand.Add( "zm_ai_speed", function(ply, cmd, args)
	if (ply:IsAdmin()) then options.BotSpeed =  tonumber(args[1]) end
end )

-- Bot Command Delay (Commanding zombies)
concommand.Add( "zm_ai_command_delay", function(ply, cmd, args)
	if (ply:IsAdmin()) then options.CommandDelay = tonumber(args[1]) end
end )

-- Bot Zombie Spawn Delay
concommand.Add( "zm_ai_zombie_spawn_delay", function(ply, cmd, args)
	if (ply:IsAdmin()) then options.ZombieSpawnDelay = tonumber(args[1]) end
end )

-- Bot Max Zombies Per Player
concommand.Add( "zm_ai_max_zombies_per_player", function(ply, cmd, args)
	if (ply:IsAdmin()) then options.ZombiesPerPlayer = tonumber(args[1]) end
end )

-- Bot Max Zombie Spawn Distance
concommand.Add( "zm_ai_max_zombie_spawn_dis", function(ply, cmd, args)
	if (ply:IsAdmin()) then options.SpawnRadius = tonumber(args[1]) end
end )

-- Bot Min Zombie Spawn Distance
concommand.Add( "zm_ai_min_zombie_delete_dis", function(ply, cmd, args)
	if (ply:IsAdmin()) then options.DeleteRadius = tonumber(args[1]) end
end )

-- Bot Min Distance To Activate Trap
concommand.Add( "zm_ai_min_distance_to_act_trap", function(ply, cmd, args)
	if (ply:IsAdmin()) then 
		options.MinTrapRange = tonumber(args[1])
		set_up_all_traps() -- Update traps with new number
	end
end )

-- Bot Max Distance To Activate Trap
concommand.Add( "zm_ai_max_distance_to_act_trap", function(ply, cmd, args)
	if (ply:IsAdmin()) then 
		options.MaxTrapRange = tonumber(args[1])
		set_up_all_traps() -- Update traps with new number
	end
end )

-- Toggle Debugger
concommand.Add( "zm_ai_debug", function(ply, cmd, args)
	if (ply:IsAdmin()) then 
		if (!options.Debug) then 
			--if (options.View == nil) then create_zm_view() end
			options.Debug = true 
			print("Debug Enabled")
		else 
			options.Debug = false 
			print("Debug Disabled")
		end
	end
end )

-- Toggle Force Start
concommand.Add( "zm_ai_enable_force_start", function(ply, cmd, args)
	if (ply:IsAdmin()) then 
		if (!options.SpawnForcing) then 
			options.SpawnForcing = true 
			print("Force Start Enabled")
		else 
			options.SpawnForcing = false 
			print("Force Start Disabled")
		end
	end
end )

-- Forces the round to begin
concommand.Add( "zm_ai_force_start_round", function(ply, cmd, args)
	if (ply:IsAdmin()) then 
		gamemode.Call("EndRound")
		zmBot:Say("Round forcefully started")
	end
end)

-- Move Player To Last spawned Zombie Spawn
concommand.Add( "zm_ai_move_ply_to_last_spawn", function(ply, cmd, args)
	if ((options.LastSpawned != nil) && (ply:IsAdmin())) then ply:SetPos(options.LastSpawned:GetPos()) end
end )


-- Enabled the AI
concommand.Add( "zm_ai_enabled", function(ply, cmd, args)
	if (ply:IsAdmin()) then 
		if (!options.Playing) then 
			if ((get_amount_zm_bots() == 0) && (#player.GetAll() > 0)) then create_zm_bot() end -- Rejoins the bot
			options.Playing = true
			print("AI Enabled")
		else 
			zmBot:Kick("AI Terminated") -- Kicks the bot
			options.Playing = false 
			print("AI Disabled")
		end
	end
end )

end