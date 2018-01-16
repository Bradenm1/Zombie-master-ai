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
local speedDelay, spawnDelay, commandDelay = 0, 0, 0 -- Delays
local zmBot = nil -- Where the player bot is stored, this is more effiencent since don't need to loop though all bots

-- Bot Options
-- Chance: 0.0 never use 1.0 always use
-- Radius/Range: Units
-- Theses are the default stats
-- Reset each round
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
	BotSpeed			= 1, -- Delay in seconds, speed of the bot as a whole
	ZombieSpawnDelay 	= 3, -- Delay in seconds, zombie spawn delay
	CommandDelay 		= 1, -- Delay in seconds, command zombie delay
	Playing				= true, -- If the bot is currently playing
	SpawnForcing		= true, -- Forces players to spawn on game start
	DynamicTraps		= false, -- If traps chances and actiavtion radius change during gameplay
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

-- Checks if bot is already in the game used for debugging
-- if (get_amount_zm_bots() == 0) then zmBot = nil end

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
		if (zb != nil) then kill_zombie(zb) end
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
	commandDelay = CurTime() + options.CommandDelay
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
	-- Attempt to spawn another zombie is failed
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
	spawnDelay = CurTime() + options.ZombieSpawnDelay
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
			if (entToUse != nil) then -- If it's not the first zombie spawner
				local newDis = spawn:GetPos():Distance(player:GetPos()) -- Get Distance of new spawner
				local oldDis = entToUse:GetPos():Distance(player:GetPos()) -- Get Distance of stored spawner
				if (oldDis > newDis) then entToUse = spawn end -- Check which one is closer
			else entToUse = spawn end -- Set First Spawner in the table to check
		end
	end
	if (entToUse == nil) then return nil end
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
-- @param arg4 Integer: Vector position for trap
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
		set_trap_settings(1255, nil, nil, Vector(-1281, -1952, -948), true) -- Red block that falls with hole in center
		local tp = Vector(-734, -1215, -911)
		set_trap_settings(2437, nil, nil, tp, true) -- tp
		set_trap_settings(2220, nil, nil, tp, true) -- tp
		set_trap_settings(2215, nil, nil, tp, true) -- tp
		local path = Vector(731, -2085, -834)
		set_trap_settings(1264, nil, nil, path, true) -- path
		set_trap_settings(1265, nil, nil, path, true) -- path
		set_trap_settings(1266, nil, nil, path, true) -- path
		local laser = Vector(22, -189, -663)
		set_trap_settings(2379, nil, nil, laser, true) -- laser
		set_trap_settings(2393, nil, nil, laser, true) -- laser
		set_trap_settings(2393, nil, nil, laser, true) -- laser
		set_trap_settings(1275, nil, nil, Vector(605, -1462, -175), true) -- red wall
	elseif (map == "zm_gasdump_b4") then
		set_trap_settings(2452, 0.02, 2096, nil, false) -- Tornado
	elseif (map == "zm_backwoods_b4") then
		-- Trigger is in not the best spot for these trap doors
		set_trap_settings(2015, nil, nil, Vector(-2290, 2322, -231), true) -- First trap door
		set_trap_settings(2016, nil, nil, Vector(-3057, 2326, -227), true) -- Second trap door
		set_trap_settings(2350, nil, nil, Vector(-5731, 7199, -229), true) -- Third trap door
		set_trap_settings(2367, nil, nil, Vector(-7438, 7187, -229), true) -- Fourth trap door
		set_trap_settings(1260, nil, nil, Vector(-4352, 7494, -23), false) -- Tall Building
	elseif (map == "zm_basin_b3fix") then
		set_trap_settings(2656, nil, nil, Vector(-3599, 22, 303), true) -- Kill AFKs
		set_trap_settings(2353, nil, nil, Vector(-722, -2255, -167), false) -- First gate
		set_trap_settings(2689, nil, nil, Vector(1794, -2143, 126), true) -- Hanging timber outside hanger door
		set_trap_settings(2342, nil, nil, Vector(1768, -3061, 146), true) -- Drop building overhanging roof
		set_trap_settings(2367, nil, nil, Vector(2861, -2513, 142), false) -- Second Gate
		set_trap_settings(2710, nil, nil, Vector(3576, 1920, 173), true) -- Motor Bomb
		set_trap_settings(2585, nil, nil, Vector(2096, 3466, 151), true) -- Trailer cannon explosion
		set_trap_settings(2608, nil, nil, Vector(-799, 4488, 105), true) -- Drop Trailer over railing
		set_trap_settings(2518, nil, nil, Vector(-2546, 2752, 105), false) -- Open building near boat
	elseif (map == "zm_diamondshoals_a2") then
		set_trap_settings(2154, nil, nil, Vector(608, 3188, -1007), false) -- FLoating explosive barrel boat
		set_trap_settings(2163, nil, nil, Vector(1418, 5481, -872), true) -- Crab Sign
	elseif (map == "zm_bluevelvet_rc1") then
		set_trap_settings(2149, nil, nil, Vector(-2033, 1913, -152), false) -- Auto Opening door
		set_trap_settings(2187, nil, nil, nil, false) -- Door
		set_trap_settings(1825, nil, nil, nil, false) -- Same door
		set_trap_settings(3373, nil, nil, Vector(-6015, 847, -553), false) -- spawn immolator near door to cut at trains
		set_trap_settings(3396, nil, nil, Vector(-3227, 983, -542), false) -- spawn banshees opposite side
	elseif (map == "zm_countrytrain_b4") then
		set_trap_settings(2997, nil, nil, Vector(-667, 1517, 63), false) -- Dumb rock
		set_trap_settings(3244, nil, nil, Vector(907, -503, 46), false) -- Second falling gate
		set_trap_settings(3025, nil, nil, Vector(27, 2492, 46), false) -- Throw rocks onto train tracks
		set_trap_settings(3248, nil, nil, Vector(2805, 1149, 25), false) -- First falling gate
		set_trap_settings(1671, nil, nil, Vector(2849, -597, 37), true) -- Send banshee into shed roof window
		set_trap_settings(3288, nil, nil, Vector(1512, 577, 32), false) -- Spawn two hulks
		set_trap_settings(2498, nil, nil, Vector(2126, -75, 51), false) -- Spawn immolator
		set_trap_settings(3208, nil, nil, Vector(-1879, 2111, 50), false) -- Spawn banshee onto of spawn building
		set_trap_settings(3008, nil, nil, Vector(598, 37, 114), false) -- Falling rocks at second gate
		set_trap_settings(2008, nil, nil, Vector(-563, -1011, 51), false) -- Raise 2 immolators at gas station
		set_trap_settings(2995, nil, nil, Vector(-1146, 368, 59), false) -- Falling rocks on path
	elseif (map == "zm_forestroad") then
		set_trap_settings(2047, nil, nil, Vector(2041, 1275, 267), true) -- Zap shed
		set_trap_settings(2254, nil, nil, Vector(4367, -1463, 86), false) -- Oil fire
		set_trap_settings(2049, nil, nil, Vector(4742, -2415, 64), true) -- Drop giant rock
	end
end

----------------------------------------------------
-- activate_trap()
-- Triggers a trap
-- @param arg1 Entity: The trap to be activated
-- @param arg2 Float: Chance for the trap to be used -- Only passed in if dynamic is false
-- @param arg3 Integer: Used for removing of trap from list
----------------------------------------------------
local function activate_trap(...)
	local arguments = {...} -- Arg1 is the Entity, Arg2 is the chance for that entity depending on if dynamic is enabled
	local chance = arguments[2] or options.UseTrapChance -- Default chance only used if errors occur
	if (chance < math.Rand(0, 1)) then return nil end -- Check chances of using the trap
	arguments[1]:Trigger(zmBot)
	options.LastTrapUsed = arguments[1]
	zmBot:TakeZMPoints(arguments[1]:GetCost())
	if (options.Debug) then zmBot:Say("Trap activated.") end -- Debugging
	if (options.DynamicTraps) then -- Set new chances
		options.UseTrapChance = get_chance_trap()
		options.TrapUsageRadius = get_trap_usage_radius()
		if (options.Debug) then debug_show_stats() end -- Show new chances
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
			local radius, chance, visible = 128, 0.5, true
			if (options.DynamicTraps) then radius = options.TrapUsageRadius else  -- Checks if dynamic is true
				for __, keyFromTrapTb in pairs(options.Traps) do -- Checks both keys to find the trap in the traps table that's being checked
					if (ent:MapCreationID() == keyFromTrapTb.Trap) then -- If it's the same trap being checked as the one in the traps table
						radius = keyFromTrapTb.TrapUsageRadius -- Get the stored radius
						chance = keyFromTrapTb.UseTrapChance -- Get the stored chance
						ent:SetPos(keyFromTrapTb.Position) -- Get position trap needs to be set to
						visible = keyFromTrapTb.HasToBeVisible
					end
				end 
			end
			for ___, ply in RandomPairs(ents.FindInSphere(ent:GetPos(), radius)) do -- Checks if any players within given radius of the trap
				if ((ply:IsPlayer()) && (ent:GetActive())) then -- Check if entity is player 
					if (!ply.IsZMBot) then 
						local canUse = true
						if (visible) then -- If it matters if the trap is visible
							if (!ent:Visible(ply)) then -- is not visible to the trap
								canUse = false
							end 
						end
						if (options.Debug) then zmBot:Say(ply:Nick() .. " Is within a trap at of radius: " .. radius .. " of chance: " .. chance .. " at going off.") end
						if ((options.DynamicTraps) && (canUse)) then return ent else return ent, chance end -- Non dynamic returns the ent and also the chance and the key
					end
				end 
			end
		end
	end
	return nil -- If no traps were found
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
-- set_up_all_traps()
-- Sets up all the traps from the get go with stats
----------------------------------------------------
local function set_up_all_traps()
	for _, ent in pairs(ents.FindByClass("info_manipulate")) do  -- Gets all traps
		table.insert( options.Traps, {
			Trap = ent:MapCreationID(),
			UseTrapChance = get_chance_trap(),
			TrapUsageRadius = get_trap_usage_radius(),
			Position = ent:GetPos(), -- Incase we need to fake it
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
		if (!options.DynamicTraps) then set_up_all_traps() else
			options.UseTrapChance = get_chance_trap()
			options.SpawnZombieChance = get_chance_spawn()
			options.TrapUsageRadius = get_trap_usage_radius()
			--if (options.Debug) then create_zm_view() end
		end
		if ((options.Debug) && (dynamicTraps)) then debug_show_stats() end
		set_map_trap_settings() -- Has to be after
		SetGlobalBool("zm_round_active", true) -- Fixes hud issue
		options.Debug = false
		options.View = nil
		options.SetUp = false
	else -- Dynamic stats, that can change during the game
		options.MaxZombies = get_max_zombies()
	end
end

----------------------------------------------------
-- zm_brain()
-- Main Entry point of bot
----------------------------------------------------
local function zm_brain()
	set_zm_settings()
	if (zmBot:Team() == ZOMBIEMASTERTEAM) then -- Checks if bot is ZM
		-- Code for running bot should go in statement
		if ((#team.GetPlayers(HUMANTEAM) > 0) && (CurTime() > speedDelay)) then -- Checks if there's players still playing as survivors
			local cloestSpawnPoint = check_for_closest_spawner() -- Check cloest spawn to players
			if ((cloestSpawnPoint != nil) && (CurTime() > spawnDelay)) then spawn_zombie(cloestSpawnPoint) end -- Spawn zombie
			local trapToUse, trapKey = check_for_traps() -- Check if player is near trap
			if (trapToUse != nil) then activate_trap(trapToUse, trapKey) end -- Use trap
			local zombiesToDelete = get_zombie_too_far() -- Gets zombies too far away from players
			if (zombiesToDelete != nil) then kill_all_zombies(zombiesToDelete) end -- Kills given zombies
			if (CurTime() > commandDelay) then move_zombie_to_player() end -- Move random zombie towards random player if non in view of that zombie
			speedDelay = CurTime() + options.BotSpeed -- Bot delay
		end
	else -- Bot is not ZM or round is over, etc..
		if (zmBot:Team() == HUMANTEAM) then if (zmBot:Alive()) then zmBot:Kill() end end -- Checks if bot is a survivor, if so kills himself
		--gamemode.Call("SetPlayerToZombieMaster", zmBot)
		zmBot:SetZMPoints(10000)
		options.SetUp = true
	end
end

----------------------------------------------------
-- create_zm_bot()
-- Updates the action of the entity
----------------------------------------------------
local function create_zm_bot()
	-- Randomly Generates a name given the botnames file
	if ((!game.SinglePlayer()) && (#player.GetAll() < game.MaxPlayers())) then
		local bot = player.CreateNextBot( names[ math.random( #names ) ]) -- Create a bot given the name list
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
        if ((options.Playing) && (zmBot != nil)) then zm_brain() end -- Checks if the bot was created, runs the bot if so
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
    if ((options.Playing) && (zmBot != nil)) then
        return zmBot -- Force the zombie master selection to the bot
    end
end )

----------------------------------------------------	
-- CMDs
-- Console Commands for bot
----------------------------------------------------

-- Bot Global Speed Delay
concommand.Add( "zm_ai_speed", function(ply, cmd, args)
	options.BotSpeed =  tonumber(args[1])
end )

-- Bot Command Delay (Commanding zombies)
concommand.Add( "zm_ai_command_delay", function(ply, cmd, args)
	options.CommandDelay = tonumber(args[1])
end )

-- Bot Zombie Spawn Delay
concommand.Add( "zm_ai_zombie_spawn_delay", function(ply, cmd, args)
	options.ZombieSpawnDelay = tonumber(args[1])
end )

-- Bot Max Zombies Per Player
concommand.Add( "zm_ai_max_zombies_per_player", function(ply, cmd, args)
	options.ZombiesPerPlayer = tonumber(args[1])
end )

-- Bot Max Zombie Spawn Distance
concommand.Add( "zm_ai_max_zombie_spawn_dis", function(ply, cmd, args)
	options.SpawnRadius = tonumber(args[1])
end )

-- Bot Min Zombie Spawn Distance
concommand.Add( "zm_ai_min_zombie_delete_dis", function(ply, cmd, args)
	options.DeleteRadius = tonumber(args[1])
end )

-- Bot Min Distance To Activate Trap
concommand.Add( "zm_ai_min_distance_to_act_trap", function(ply, cmd, args)
	options.MinTrapRange = tonumber(args[1])
	set_up_all_traps() -- Update traps with new number
end )

-- Bot Max Distance To Activate Trap
concommand.Add( "zm_ai_max_distance_to_act_trap", function(ply, cmd, args)
	options.MaxTrapRange = tonumber(args[1])
	set_up_all_traps() -- Update traps with new number
end )

-- If Traps Are Dynamic
concommand.Add( "zm_ai_dynamic_traps", function(ply, cmd, args)
	if (!options.DynamicTraps) then 
		options.DynamicTraps = true 
		print("Dynamic Enabled")
	else 
		options.DynamicTraps = false 
		print("Disabled Enabled")
	end
end )

-- Toggle Debugger
concommand.Add( "zm_ai_debug", function(ply, cmd, args)
	if (!options.Debug) then 
		--if (options.View == nil) then create_zm_view() end
		options.Debug = true 
		print("Debug Enabled")
	else 
		options.Debug = false 
		print("Debug Disabled")
	end
end )

-- Toggle Force Start
concommand.Add( "zm_ai_enable_force_start", function(ply, cmd, args)
	if (!options.SpawnForcing) then 
		options.SpawnForcing = true 
		print("Force Start Enabled")
	else 
		options.SpawnForcing = false 
		print("Force Start Disabled")
	end
end )

-- Forces the round to begin
concommand.Add( "zm_ai_force_start_round", function(ply, cmd, args)
	gamemode.Call("EndRound")
	zmBot:Say("Round forcefully started")
end)

-- Move Player To Last spawned Zombie Spawn
concommand.Add( "zm_ai_move_ply_to_last_spawn", function(ply, cmd, args)
	if (options.LastSpawned != nil) then ply:SetPos(options.LastSpawned:GetPos()) end
end )


-- Enabled the AI
concommand.Add( "zm_ai_enabled", function(ply, cmd, args)
	if (!options.Playing) then 
		if ((get_amount_zm_bots() == 0) && (#player.GetAll() > 0)) then create_zm_bot() end -- Rejoins the bot
		options.Playing = true
		print("AI Enabled")
	else 
		zmBot:Kick("AI Terminated") -- Kicks the bot
		options.Playing = false 
		print("AI Disabled")
	end
end )

end