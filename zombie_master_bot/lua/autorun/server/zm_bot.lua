include("botnames.lua")

-- Saving while playing and editing the bot will break it

-- Constants
local GAMEMODE = "zombiemaster"
local HUMANTEAM = 1
local ZOMBIEMASTERTEAM = 2
local SPECTATORTEAM = 3

-- Delays
local SPEEDDELAY = CurTime()
local SPAWNDELAY = CurTime()
local COMMANDDELAY = CurTime()


local zmBot = nil -- Where the player bot is stored, this is more effiencent since don't need to loop though all bots
local playing = true -- If the bot is currently playing
local lastSpawned = nil

-- Bot Options
-- Chance: 0.0 never use 1.0 always use
-- Theses are the default stats
local options = {
	MaxZombies 			= 60, -- Max zombies this changes depending on the players
	SpawnRadius			= 3000, -- Max Spawn distance
	DeleteRadius 		= 3000, -- Min distance to delete zombies
	ZombiesPerPlayer	= 14, -- Zombies per player on the server
	MinTrapRange		= 92, -- Min range to use trap around players
	MaxTrapRange 		= 224, -- Max range to use trap around players
	TrapUsageRadius		= 128, -- Max distance to use a trap when a player is near
	UseTrapChance  		= 0.2, -- Use Trap Chance
	SpawnZombieChance	= 0.5, -- Zombie Spawn Chance
	BotSpeed			= 1, -- Delay in seconds, Speed of the bot as a whole
	ZombieSpawnDelay 	= 3, -- Delay in seconds
	CommandDelay 		= 1, -- Delay in seconds
	DynamicTraps		= false, -- If traps chances and actiavtion radius change during gameplay
								 -- True means it changes on the fly each time a trap is used
								 -- False means it does not and all traps have set chances and ranges from the start of the round
	Debug 				= false, -- Used for basic debugging
	SetUp 				= false, -- Setup for the bot
	Traps				= {} -- Used to stored the traps at round starts if dynamic is false
}

-- Types of Zombies the AI spawn
-- These are the class names
-- Custom npcs should have prefix of "npc_"
local zombieTypes = {
	"npc_zombie",
	"npc_fastzombie",
	"npc_dragzombie",
	"npc_poisonzombie",
	"npc_burnzombie"
}

----------------------------------------------------
-- get_amount_zm_bots()
-- Returns amount of Zombie Master bots
-- @return amount Integer: Amount of bots
----------------------------------------------------
function get_amount_zm_bots()
	local amount = 0
	for _, bot in pairs(player.GetBots()) do 
		if (bot.IsZMBot) then amount = amount + 1 end
	end
	return amount
end

-- Checks if bot is already in the game used for debugging
-- if (get_amount_zm_bots() == 0) then zmBot = nil end

----------------------------------------------------
-- CreatePlayerBot()
-- Updates the action of the entity
----------------------------------------------------
function create_player_bot()
	-- Randomly Generates a name given the botnames file
	if ((!game.SinglePlayer()) && (#player.GetAll() < game.MaxPlayers())) then
		local bot = player.CreateNextBot( names[ math.random( #names ) ]) -- Create a bot given the name list
		bot.IsZMBot = true -- Set bot as ZM bot
		zmBot = bot -- Assign bot as global for usage
	else print( "Cannot create bot. Do you have free slots or are you in Single Player?" ) end -- This prints to console if the bot cannot spawn
end

----------------------------------------------------
-- bot_brain()
-- Main Entry point of bot
----------------------------------------------------
function bot_brain()
	set_up_stats()
	if (zmBot:Team() == ZOMBIEMASTERTEAM) then -- Checks if bot is ZM
		-- Code for running bot should go in statement
		if ((#team.GetPlayers(HUMANTEAM) > 0) && (CurTime() > SPEEDDELAY)) then activators() end -- Checks if there's players still playing as survivors
	else -- Bot is not ZM or round is over, etc..
		if (zmBot:Team() == HUMANTEAM) then if (zmBot:Alive()) then zmBot:Kill() end end -- Checks if bot is a survivor, if so kills himself
		gamemode.Call("SetPlayerToZombieMaster", zmBot)
		zmBot:SetZMPoints(1000000)
		options.SetUp = false
	end
end

----------------------------------------------------
-- set_up_stats()
-- Sets up the bots stats
----------------------------------------------------
function set_up_stats()
	if (!options.SetUp) then -- The setup for the bot 
		-- This section is done once during the round start
		if (!options.DynamicTraps) then set_up_all_traps() else
			options.UseTrapChance = get_chance()
			options.SpawnZombieChance = get_chance()
			options.TrapUsageRadius = get_trap_usage_radius()
		end
		if ((options.Debug) && (dynamicTraps)) then debug_show_stats() end
		SetGlobalBool("zm_round_active", true) -- Fixes hud issue
		options.SetUp = true
	else -- Dynamic stats, that can change during the game
		options.MaxZombies = get_max_zombies()
	end
end

----------------------------------------------------
-- set_up_all_traps()
-- Sets up all the traps from the get go with stats
----------------------------------------------------
function set_up_all_traps()
	for _, ent in pairs(ents.FindByClass("info_manipulate")) do  -- Gets all traps
		table.insert( options.Traps, {
			Trap = _,
			UseTrapChance = get_chance(),
			TrapUsageRadius = get_trap_usage_radius()
		})
	end
	--PrintTable(traps)
end

----------------------------------------------------
-- debug_show_stats()
-- Shows stats of bot
----------------------------------------------------
function debug_show_stats()
	zmBot:Say("Use Trap Chance: " .. options.UseTrapChance)
	zmBot:Say("Spawn Zombie Chance: " .. options.SpawnZombieChance)
	zmBot:Say("Trap Usage Radius: " .. options.TrapUsageRadius)
end

----------------------------------------------------
-- activators()
-- Runs the triggers for the bot
----------------------------------------------------
function activators()
	local cloestSpawnPoint = check_for_closest_spawner() -- Check cloest spawn to players
	if ((cloestSpawnPoint != nil) && (CurTime() > SPAWNDELAY)) then spawn_zombie(cloestSpawnPoint) end -- Spawn zombie
	local trapToUse, trapKey, tbKey = check_for_traps() -- Check if player is near trap
	if (trapToUse != nil) then activate_trap(trapToUse, trapKey, tbKey) end -- Use trap
	local zombiesToDelete = get_zombie_too_far() -- Gets zombies too far away from players
	if (zombiesToDelete != nil) then kill_all_zombies(zombiesToDelete) end -- Kills given zombies
	if (CurTime() > COMMANDDELAY) then move_zombie_to_player() end -- Move random zombie towards random player if non in view of that zombie
	SPEEDDELAY = CurTime() + options.BotSpeed -- Bot delay
end

----------------------------------------------------
-- check_for_traps()
-- Checks for traps within radius of players
-- @return ent Entity: Trap which has been found
----------------------------------------------------
function check_for_traps()
	for key, ent in pairs(ents.FindByClass("info_manipulate")) do  -- Gets all traps
		if (IsValid(ent)) then -- Check if trap is vaild and not used
			local radius = 128 -- Default Radius only used if errors occur
			local chance = 0.5 -- Default Chance only used if errors occur
			if (options.DynamicTraps) then radius = options.TrapUsageRadius else  -- Checks if dynamic is true
				for __, keyFromTrapTb in pairs(options.Traps) do -- Checks both keys to find the trap in the traps table that's being checked
					if (key == keyFromTrapTb.Trap) then -- If it's the same trap being checked as the one in the traps table
						radius = keyFromTrapTb.TrapUsageRadius -- Get the stored radius
						chance = keyFromTrapTb.UseTrapChance -- Get the stored chance
					end
				end 
			end
			for ___, ply in pairs(ents.FindInSphere(ent:GetPos(), radius)) do -- Checks if any players within given radius of the trap
				if ((ply:IsPlayer()) && (ent:Visible(ply)) && (ent:GetActive())) then 
					if (options.Debug) then zmBot:Say(ply:Nick() .. " Is within a trap at of radius: " .. radius .. " of chance: " .. chance .. " at going off.") end
					if (options.DynamicTraps) then return ent else return ent, chance, key end -- Non dynamic returns the ent and also the chance and the key
				end -- Check if entity is player and is visible to the trap
			end
		end
	end
	return nil -- If no traps were found
end

----------------------------------------------------
-- activate_trap()
-- Triggers a trap
-- @param arg1 Entity: The trap to be activated
-- @param arg2 Float: Chance for the trap to be used -- Only passed in if dynamic is false
-- @param arg3 Integer: Used for removing of trap from list
----------------------------------------------------
function activate_trap(...)
	local arguments = {...} -- Arg1 is the Entity, Arg2 is the chance for that entity depending on if dynamic is enabled
	local chance = 0.5 -- Default chance only used if errors occur
	if (options.DynamicTraps) then chance = options.UseTrapChance else chance = arguments[2] end -- Check if traps are set to dynamic
	if (chance < math.Rand(0, 1)) then return nil end -- Check chances of using the trap
	arguments[1]:Trigger(zmBot)
	zmBot:TakeZMPoints(arguments[1]:GetCost())
	if (options.Debug) then zmBot:Say("Trap activated.") end -- Debugging
	if (options.DynamicTraps) then -- Set new chances
		options.UseTrapChance = get_chance()
		options.TrapUsageRadius = get_trap_usage_radius()
		if (options.Debug) then debug_show_stats() end -- Show new chances
	end
	table.remove( options.Traps, arguments[3] )
	--ent.botUsed = true
end

----------------------------------------------------
-- check_for_spawner()
-- Finds zombies spawners and spawns a zombie
-- @return entToUse Entity: cloeset spawner
----------------------------------------------------
function check_for_closest_spawner()
	if (get_zombie_amount() > options.MaxZombies) then return nil end
	local zombieSpawns = ents.FindByClass("info_zombiespawn")
	if (#zombieSpawns == 0) then return nil end -- Checks if there's any spawns
	local player = table.Random(team.GetPlayers(HUMANTEAM)) -- Picks a random player from humanteam
	local entToUse = nil -- Default to nil
	for __, spawn in pairs(zombieSpawns) do -- Find cloest spawn point
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
-- pick_zombie()
-- Picks a random zombie
-- @return zb String: The zombie to use as class
----------------------------------------------------
function pick_zombie()
	local zb = zombieTypes[1] -- Default zombie
	for i=1, #zombieTypes do -- Pick random zombie, not zero based
		if (get_zombie_chance() == 0) then zb = zombieTypes[i] end -- Checks if this is the zombie to use
	end
	return zb
end

----------------------------------------------------
-- get_zombie_chance()
-- Returns the chance of picking a zombie
-- @return chance Integer: chance
----------------------------------------------------
function get_zombie_chance()
	local chance = math.random(0, 10) % 9
	return chance
end

----------------------------------------------------
-- spawn_zombie()
-- Spawns a zombie
-- @param ent Entity: Spawn to spawn zombie at
----------------------------------------------------
function spawn_zombie(ent)
	if (options.SpawnZombieChance < math.Rand(0, 1)) then return nil end
	local zb = pick_zombie()
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
	lastSpawned = ent
	if (options.Debug) then zmBot:Say("Attempted to spawn: " .. zb) end
	SPAWNDELAY = CurTime() + options.ZombieSpawnDelay
end

----------------------------------------------------
-- get_zombie_too_far()
-- Checks for zombies too far away from players and deletes them
-- @return zombies Table: zombies too far away
----------------------------------------------------
function get_zombie_too_far()
	local zombies = {}
	local index = 0
	for _, ply in pairs(team.GetPlayers(HUMANTEAM)) do -- Loop through survivors
		for __, zb in pairs(ents.FindByClass("npc_*")) do -- Loop through all zombies
			if ((zb:GetClass() != "npc_maker")) then
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
-- kill_all_zombies()
-- Kills all zombies within a table
-- @param tb Table: table containting zombies
----------------------------------------------------
function kill_all_zombies(tb)
	for _, zb in pairs(tb) do
		if (zb != nil) then kill_zombie(zb) end
	end
end

----------------------------------------------------
-- kill_zombie()
-- Kills a given zombie
-- @param zb Entity: Zombie to be deleted
----------------------------------------------------
function kill_zombie(zb)
	if (options.Debug) then zmBot:Say("Zombie Has been killed and removed, to far away from any players.") end
	local dmginfo = DamageInfo()
	dmginfo:SetDamage(zb:Health() * 1.25)
	zb:TakeDamageInfo(dmginfo) 
	zb:Remove()
end


----------------------------------------------------
-- move_zombies_to_players()
-- Moves random zombie to random player
----------------------------------------------------
function move_zombie_to_player()
	local player = table.Random(team.GetPlayers(HUMANTEAM)) -- Get Random survivor
	local zm = table.Random(ents.FindByClass("npc_*")) -- Get random zombie
	if ((IsValid(player)) && (IsValid(zm)) && (zm:GetClass() != "npc_maker")) then zm:ForceGo(player:GetPos()) end
	COMMANDDELAY = CurTime() + options.CommandDelay
end

----------------------------------------------------
-- get_zombie_amount()
-- Gets amount of zombies currently on the map
-- @return amount Integer: amount of zombies
----------------------------------------------------
function get_zombie_amount()
	local amount = 0
	for __, zb in pairs(ents.FindByClass("npc_*")) do -- Loop through all zombies
		if ((zb:GetClass() != "npc_maker")) then amount = amount + 1 end -- Check if it's a zombie
	end
	return amount
end

----------------------------------------------------
-- get_max_zombies()
-- Gets the max zombies
-- @return maxZombies Integer: max zombies
----------------------------------------------------
function get_max_zombies()
	local maxZombies = #team.GetPlayers(HUMANTEAM) * options.ZombiesPerPlayer
	return maxZombies
end

----------------------------------------------------
-- get_chance()
-- Returns a random decimnal number
-- @return chance Float: chance
----------------------------------------------------
function get_chance()
	local chance = math.Rand(0.03, 1) -- 0.03 would be 3% and 1 would be 100%
	return chance
end

----------------------------------------------------
-- get_trap_usage_radius()
-- Returns a random Integer number
-- @return radius Integer: returns an amount
----------------------------------------------------
function get_trap_usage_radius()
	local radius = math.random(options.MinTrapRange, options.MaxTrapRange) -- 128 to 192
	return radius
end

----------------------------------------------------	
-- Think
-- Think hook for controlling the bot
----------------------------------------------------
hook.Add( "Think", "Control_Bot", function()
	if (engine.ActiveGamemode() != GAMEMODE) then -- Checking if gamemode is active
		print("Zombie Master Gamemode not active, disabling ZM AI")
		hook.Remove( "Think", "Control_Bot" ) -- Disables the mod is not active
	else
		if (playing) then
			if ((get_amount_zm_bots() == 0) && (#player.GetAll() > 0)) then create_player_bot() end -- Check if there's already a bot on the server and waits for players to join first
			if (zmBot != nil) then bot_brain() end -- Checks if the bot was created, runs the bot if so
		end
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
	if (args[1] == "1") then options.DynamicTraps = true else options.DynamicTraps = false end
end )

-- Enable Debugger
concommand.Add( "zm_ai_debug", function(ply, cmd, args)
	if (args[1] == "1") then options.Debug = true else options.Debug = false end
end )

-- Move Player To Last spawned Zombie Spawn
concommand.Add( "zm_ai_move_ply_to_last_spawn", function(ply, cmd, args)
	if (lastSpawned != nil) then ply:SetPos(lastSpawned:GetPos()) end
end )


-- Enabled the AI
concommand.Add( "zm_ai_enabled", function(ply, cmd, args)
	if (args[1] == "1") then 
		if ((get_amount_zm_bots() == 0) && (#player.GetAll() > 0)) then create_player_bot() end -- Rejoins the bot
		playing = true
	else 
		zmBot:Kick("AI Terminated") -- Kicks the bot
		playing = false 
	end
end )