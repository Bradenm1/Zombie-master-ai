include("botnames.lua")

-- Saving while playing and editing the bot will break it

-- Globals
local HUMANTEAM = 1
local ZOMBIEMASTERTEAM = 2
local ZOMBIESPERPLAYER = 14

-- Delays
local SPEEDDELAY = CurTime()
local SPAWNDELAY = CurTime()
local COMMANDDELAY = CurTime()


local setUp = false -- Setup for the bot
local debug = false -- Used for basic debugging
local zmBot = nil -- Bot

-- Bot Options
-- Chance: 0.0 never use 1.0 always use
-- Theses are the default stats
local options = {
	MaxZombies 			= 60, -- Max zombies the bot can have on the map before it cannot spawn anymore
	SpawnRadius			= 3000, -- Max Spawn distance
	DeleteRadius 		= 3000, -- Min distance to delete zombies
	TrapUsageRadius		= 128, -- Max distance to use a trap when a player is near
	UseTrapChance  		= 0.2, -- Use Trap Chance
	SpawnZombieChance	= 0.5, -- Zombie Spawn Chance
	BotSpeed			= 1, -- Delay in seconds, Speed of the bot as a whole
	ZombieSpawnDelay 	= 3, -- Delay in seconds
	CommandDelay 		= 1 -- Delay in seconds
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
		zmBot:SetTeam(ZOMBIEMASTERTEAM)
		zmBot:SetZMPoints(1000000)
		setUp = false
	end
end

----------------------------------------------------
-- set_up_stats()
-- Sets up the bots stats
----------------------------------------------------
function set_up_stats()
	if (!setUp) then -- The setup for the bot 
		-- This section is done once during the round start
		options.UseTrapChance = get_chance()
		options.SpawnZombieChance = get_chance()
		options.TrapUsageRadius = get_trap_usage_radius()
		SetGlobalBool("zm_round_active", true) -- Fixes hud issue
		if (debug) then debug_show_stats() end
		setUp = true
	else -- Dynamic stats, that can change during the game
		options.MaxZombies = get_max_zombies()
	end
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
	local trapToUse = check_for_traps() -- Check if player is near trap
	if (trapToUse != nil) then activate_trap(trapToUse) end -- Use trap
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
	for __, ent in pairs(ents.FindByClass("info_manipulate")) do  -- Gets all traps
		-- ((IsValid(ent)) && (!ent.botUsed))
		if (IsValid(ent)) then -- Check if trap is vaild and not used
			for ___, ply in pairs(ents.FindInSphere(ent:GetPos(), options.TrapUsageRadius)) do -- Checks if any players within given radius of the trap
				if ((ply:IsPlayer()) && (ent:Visible(ply)) && (ent:GetActive())) then return ent end -- Check if entity is player and is visible to the trap
			end
		end
	end
	return nil -- If no traps were found
end

----------------------------------------------------
-- activate_trap()
-- Triggers a trap
-- @param ent Entity: The trap to be activated
----------------------------------------------------
function activate_trap(ent)
	if (options.UseTrapChance < math.Rand(0, 1)) then return nil end
	ent:Trigger(zmBot)
	zmBot:TakeZMPoints(ent:GetCost())
	if (debug) then zmBot:Say("Trap activated.") end
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
	ent:AddQuery(zmBot, zb, 1)
	if (debug) then zmBot:Say(zb .. " spawned") end
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
	if (debug) then zmBot:Say("Zombie Has been killed and removed, to far away from any players.") end
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
	local maxZombies = #team.GetPlayers(HUMANTEAM) * ZOMBIESPERPLAYER
	return maxZombies
end

----------------------------------------------------
-- get_chance()
-- Returns a random decimnal number
-- @return chance Float: chance
----------------------------------------------------
function get_chance()
	local chance = math.Rand(0.1, 1)
	return chance
end

----------------------------------------------------
-- get_trap_usage_radius()
-- Returns a random Integer number
-- @return radius Integer: returns an amount
----------------------------------------------------
function get_trap_usage_radius()
	local radius = math.random(128, 192)
	return radius
end

----------------------------------------------------	
-- Think
-- Think hook for controlling the bot
----------------------------------------------------
hook.Add( "Think", "Control_Bot", function()
	if ((get_amount_zm_bots() == 0) && (#player.GetAll() > 0)) then create_player_bot() end -- Check if there's already a bot on the server and waits for players to join first
	if (zmBot != nil) then bot_brain() end -- Checks if the bot was created, runs the bot if so
end )