include("botnames.lua")
include("obj_player_bot_extend.lua")

-- Globals
local SPAWNANDDELETEDIS = 3000
local MAXZOMBIES = 15

-- Checks if bot is already in the game used for debugging
if (#player.GetBots() == 0) then zmBot = nil end

-- Command to spawn bot
concommand.Add( "spawnBot", function()
	create_player_bot()
end )

-- Command to kill bots
concommand.Add( "killAll", function()
	for _, player in pairs(player.GetAll()) do	
		if (player.IsZMBot) then
			player:Kill()
		end
	end
end )

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
	else print( "Cannot create bot. Are you in Single Player?" ) end
end

----------------------------------------------------
-- bot_brain()
-- Main Entry point of bot
----------------------------------------------------
function bot_brain()
	if (zmBot:Team() == 2) then -- Checks if bot is ZM
		if (#team.GetPlayers(1) > 0) then check_for_triggers() end
	else
		if (zmBot:Team() == 1) then if (zmBot:Alive()) then zmBot:Kill() end end
		zmBot:SetTeam(2)
	end
end

----------------------------------------------------
-- check_for_traps()
-- Checks for triggers
----------------------------------------------------
function check_for_triggers()
	check_for_traps()
	check_for_spawner()
	get_zombie_too_far()
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
					activate_trap(ent)
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
	print(ent)
	ent:Trigger(zmBot)
	zmBot:TakeZMPoints(ent:GetCost())
	ent.botUsed = true
end

----------------------------------------------------
-- check_for_spawner()
-- Finds zombies spawners and spawns a zombie
----------------------------------------------------
function check_for_spawner()
	 -- Pick a Random Player
	if (self.ZombiesSpawn < MAXZOMBIES) then
		local player = table.Random(team.GetPlayers(1))
		-- Finds closest spawner to a player
		local pickFirst = false
		local entToUse = nil
		
		for __, spawn in pairs(ents.FindByClass("info_zombiespawn")) do -- Find cloest spawn point
			if (IsValid(spawn)) then
				if (!pickFirst) then -- Set First Spawner
					entToUse = spawn 
					pickFirst = true
				else
					dis = spawn:GetPos():Distance(player:GetPos()) -- Get Distance
					if ((entToUse:GetPos():Distance(player:GetPos()) > dis) && (spawn:GetPos():Distance(player:GetPos()) < SPAWNANDDELETEDIS)) then entToUse = spawn end -- Check if it's closer
				end
			end
		end
		if (entToUse) then -- Use cloest spawn point if there's one
			spawn_zombie(entToUse)
		end
	end
end

----------------------------------------------------
-- spawn_zombie()
-- Spawns a zombie
----------------------------------------------------
function spawn_zombie(ent)
	print("ads")
	ent:AddQuery(zmBot, "npc_zombie", 1)
	self.ZombiesSpawn = self.ZombiesSpawn + 1
end

----------------------------------------------------
-- get_zombie_too_far()
-- Checks for zombies too far away from players and deletes them
----------------------------------------------------
function get_zombie_too_far()
	local zombiesToDelete = {}
	local index = 0
	for _, ply in pairs(team.GetPlayers(1)) do
		for __, zb in pairs(ents.FindByClass("npc_*")) do
			if (ply:GetPos():Distance(zb:GetPos()) > SPAWNANDDELETEDIS) then 
				zombiesToDelete[index] = zb 
			else
				zombiesToDelete[index] = nil
			end
			index = index + 1
		end
		index = 0
	end
	kill_all_zombies(zombiesToDelete)
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
	self.ZombiesSpawn = self.ZombiesSpawn - 1
end

----------------------------------------------------
-- Think
-- Think hook for controlling the bot
----------------------------------------------------
hook.Add( "Think", "Control_Bot", function()
	if ((#player.GetBots() == 0) && (#player.GetAll() > 0)) then create_player_bot() end
	for _, player in pairs(player.GetBots()) do	
		if (player.IsZMBot) then
			bot_brain()
		end
	end
end )