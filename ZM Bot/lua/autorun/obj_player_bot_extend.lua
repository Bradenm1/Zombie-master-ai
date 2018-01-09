-- local SPAWNANDDELETEDIS = 3000
local meta = FindMetaTable("Player")
if not meta then return end

function meta:GetAiState()
    return self.AIState
end

function meta:SetAiState(index)
    self.AIState = index
end

function meta:SetTarget(target)
    self.Target = target
end

function meta:GetTarget()
    return self.Target
end

--[[

function meta:bot_brain()
	if (self:Team() == 2) then -- Checks if bot is ZM
		if (#team.GetPlayers(1) > 0) then self:check_for_triggers() end
	else
		if (self:Team() == 1) then if (self:Alive()) then self:Kill() end end
		self:SetTeam(2)
	end
end

function meta:check_for_triggers()
	self:check_for_traps()
	self:check_for_spawner()
	self:get_zombie_too_far()
end

function meta:check_for_traps(ply)
	for __, ent in pairs(ents.FindByClass("info_manipulate")) do 
		if ((IsValid(ent)) && (!ent.botUsed)) then
			for ___, ply in pairs(ents.FindInSphere(ent:GetPos(), 128)) do
				if ((ply:IsPlayer()) && (ent:Visible(ply))) then
					self:activate_trap(ent)
				end
			end
		end
	end
end

function meta:activate_trap(ent)
	print(ent)
	ent:Trigger(self)
	self:TakeZMPoints(ent:GetCost())
	ent.botUsed = true
end

function meta:check_for_spawner()
	 -- Pick a Random Player
	--if (self.ZombiesSpawn < 10000) then
		local player = table.Random(team.GetPlayers(1))
		-- Finds closest spawner to a player
		local pickFirst = false
		local entToUse = nil
		
		for __, ent in pairs(ents.FindByClass("info_zombiespawn")) do -- Find cloest spawn point
			if (IsValid(ent)) then
				if (!pickFirst) then -- Set First Spawner
					entToUse = ent 
					pickFirst = true
				else
					dis = ent:GetPos():Distance(player:GetPos()) -- Get Distance
					if ((entToUse:GetPos():Distance(player:GetPos()) > dis) && (ent:GetPos():Distance(player:GetPos()) < SPAWNANDDELETEDIS)) then entToUse = ent end -- Check if it's closer
				end
			end
		end
		if (entToUse) then -- Use cloest spawn point if there's one
			self:spawn_zombie(entToUse)
		end
	--end
end

function meta:spawn_zombie(ent)
	ent:AddQuery(self, "npc_zombie", 1)
	--self.ZombiesSpawn = self.ZombiesSpawn + 1
end

function meta:get_zombie_too_far()
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
	self:kill_all_zombies(zombiesToDelete)
end

function meta:kill_all_zombies(tb)
	for _, zb in pairs(tb) do
		self:kill_zombie(zb)
	end
end

function meta:kill_zombie(zb)
		local dmginfo = DamageInfo()
		dmginfo:SetDamage(zb:Health() * 1.25)
		zb:TakeDamageInfo(dmginfo) 
end

----------------------------------------------------
-- update_action()
-- Updates the action of the entity
----------------------------------------------------
function meta:update_action(bot, cmd)
	if self.AIState == 0 then -- Nothing
	elseif self.AIState == 1 then -- Idle
	elseif self.AIState == 2 then -- Set Trap
	elseif self.AIState == 3 then -- Chase
	elseif self.AIState == 4 then -- Attack
	elseif self.AIState == 5 then -- Use Item
	else -- Default
	end
end
----------------------------------------------------
-- perfom_action()
-- Performs the action of the entity
----------------------------------------------------
function meta:perfom_action(bot, cmd)
	if self.AIState == 0 then -- Nothing
	elseif self.AIState == 1 then -- Idle
	elseif self.AIState == 2 then -- Wandering
	elseif self.AIState == 3 then -- Chase
	elseif self.AIState == 4 then -- Attack
	elseif self.AIState == 5 then -- Use Item
	else -- Default
	end
end


----------------------------------------------------
-- ENT:check_targeted_exists()
-- Check if targeted Entity is alive and exists
-- @param ent Entity: The Entity to check
-- @return Boolean: False, Entity Does not Exist. True Entity Does Exist
----------------------------------------------------
function meta:check_targeted_exists( ent )
	if (ent ~= nil) && (ent:IsValid()) then
		if (ent:Health() < 0) then return false end
	else
		return false
	end
	return true
end

function meta:check_targeted_alive()
	if (self:GetTarget()) then
		return false
	end
	return true
end

]]