include("botnames.lua")

-- Globals
local SPAWNANDDELETEDIS = 3000
local MAXZOMBIES = 60

local HUMANTEAM = 1
local ZOMBIEMASTERTEAM = 2



-- Command to spawn bot
--[[concommand.Add( "spawnBot", function()
	create_player_bot()
end )
]]

----------------------------------------------------
-- get_amount_zm_bots()
-- Returns amount of Zombie Master bots
----------------------------------------------------
function get_amount_zm_bots()
	local amount = 0
	for _, bot in pairs(player.GetBots()) do 
		if (bot.IsZMBot) then
			amount = amount + 1
		end
	end
	return amount
end

-- Checks if bot is already in the game used for debugging
if (get_amount_zm_bots() == 0) then zmBot = nil end

----------------------------------------------------
-- CreatePlayerBot()
-- Updates the action of the entity
----------------------------------------------------
function create_player_bot()
	-- Randomly Generates a name given the botnames file
	if ((!game.SinglePlayer()) && (#player.GetAll() < game.MaxPlayers())) then
		local bot = player.CreateNextBot( names[ math.random( #names ) ])
		bot.IsZMBot = true
		bot.ZombiesSpawn = 0
		zmBot = bot
		bot:SetZMPoints(1000000)
	else print( "Cannot create bot. Do you have free slots or are you in Single Player?" ) end
end

----------------------------------------------------
-- bot_brain()
-- Main Entry point of bot
----------------------------------------------------
function bot_brain()
	if (zmBot:Team() == ZOMBIEMASTERTEAM) then -- Checks if bot is ZM
		if (#team.GetPlayers(HUMANTEAM) > 0) then activators() end -- Checks if there's players still playing as survivors
	else
		if (zmBot:Team() == HUMANTEAM) then if (zmBot:Alive()) then zmBot:Kill() end end
		zmBot:SetTeam(ZOMBIEMASTERTEAM)
	end
end

----------------------------------------------------
-- check_for_traps()
-- Checks for triggers
----------------------------------------------------
function activators()
	local cloestSpawnPoint = check_for_closest_spawner() -- Check cloest spawn to players
	local trapToUse = check_for_traps() -- Check if player is near trap
	local zombieTable = get_zombie_too_far() -- Gets zombies too far away from players
	if (IsValid(cloestSpawnPoint)) then spawn_zombie(cloestSpawnPoint) end -- Spawn zombie
	if (IsValid(trapToUse)) then activate_trap(trapToUse) end -- Use trap
	if (IsValid(zombieTable)) then kill_all_zombies(zombieTable) end -- Kills given zombies
	move_zombie_to_player() -- Move random zombie towards random player if non in view of that zombie
end

----------------------------------------------------
-- check_for_traps()
-- Checks for traps within radius of players
----------------------------------------------------
function check_for_traps(ply)
	for __, ent in pairs(ents.FindByClass("info_manipulate")) do 
		if ((IsValid(ent)) && (!ent.botUsed)) then
			for ___, ply in pairs(ents.FindInSphere(ent:GetPos(), 128)) do
				if ((ply:IsPlayer()) && (ent:Visible(ply))) then
					return ent -- Return a trap if close to a player and in view
				end
			end
		end
	end
end

----------------------------------------------------
-- activate_trap()
-- Triggers a trap
----------------------------------------------------
function activate_trap(ent)
	ent:Trigger(zmBot)
	zmBot:TakeZMPoints(ent:GetCost())
	ent.botUsed = true
end

----------------------------------------------------
-- check_for_spawner()
-- Finds zombies spawners and spawns a zombie
----------------------------------------------------
function check_for_closest_spawner()
	 -- Pick a Random Player
	if (zmBot.ZombiesSpawn < MAXZOMBIES) then
		local player = table.Random(team.GetPlayers(HUMANTEAM)) -- Picks a random player from humanteam
		-- Finds closest spawner to a player
		local pickFirst = false
		local entToUse = nil
		
		for __, spawn in pairs(ents.FindByClass("info_zombiespawn")) do -- Find cloest spawn point
			if (IsValid(spawn)) then
				if (!pickFirst) then -- Set First Spawner
					entToUse = spawn 
					pickFirst = true
				else
					local newDis = spawn:GetPos():Distance(player:GetPos()) -- Get Distance of new spawner
					local oldDis = entToUse:GetPos():Distance(player:GetPos()) -- Get Distance of stored spawner
					if (((oldDis) > dis) && (newDis < SPAWNANDDELETEDIS)) then entToUse = spawn end -- Check which one is closer
				end
			end
		end
		return entToUse -- Return the closest spawn
	end
end

----------------------------------------------------
-- spawn_zombie()
-- Spawns a zombie
----------------------------------------------------
function spawn_zombie(ent)
	ent:AddQuery(zmBot, "npc_zombie", 1)
	zmBot.ZombiesSpawn = zmBot.ZombiesSpawn + 1
end

----------------------------------------------------
-- get_zombie_too_far()
-- Checks for zombies too far away from players and deletes them
----------------------------------------------------
function get_zombie_too_far()
	local zombies = {}
	local index = 0
	for _, ply in pairs(team.GetPlayers(HUMANTEAM)) do
		for __, zb in pairs(ents.FindByClass("npc_*")) do
			if (ply:GetPos():Distance(zb:GetPos()) > SPAWNANDDELETEDIS) then 
				zombies[index] = zb 
			else
				zombies[index] = nil
			end
			index = index + 1
		end
		index = 0
	end
	return zombies
end

----------------------------------------------------
-- kill_all_zombies()
-- Kills all zombies within a table
----------------------------------------------------
function kill_all_zombies(tb)
	for _, zb in pairs(tb) do
		kill_zombie(zb)
	end
end

----------------------------------------------------
-- kill_zombie()
-- Kills a given zombie
----------------------------------------------------
function kill_zombie(zb)
	local dmginfo = DamageInfo()
	dmginfo:SetDamage(zb:Health() * 1.25)
	zb:TakeDamageInfo(dmginfo) 
	zmBot.ZombiesSpawn = zmBot.ZombiesSpawn - 1
end


----------------------------------------------------
-- move_zombies_to_players()
-- Moves random zombie to random player
----------------------------------------------------
function move_zombie_to_player()
	local player = table.Random(team.GetPlayers(HUMANTEAM)) -- Get Random survivor
	local zm = table.Random(ents.FindByClass("npc_*")) -- Get random zombie
	if ((IsValid(player)) && (IsValid(zm)) && (zm:GetClass() != "npc_maker") && (!player:Visible(zm))) then zm:ForceGo(player:GetPos()) end
end

----------------------------------------------------	
-- Think
-- Think hook for controlling the bot
----------------------------------------------------
hook.Add( "Think", "Control_Bot", function()
	if ((get_amount_zm_bots() == 0) && (#player.GetAll() > 0)) then create_player_bot() end -- Check if there's already a bot on the server and waits for players to join first
	if (zmBot) then bot_brain() end -- Checks if the bot was created, runs the bot if so
end )