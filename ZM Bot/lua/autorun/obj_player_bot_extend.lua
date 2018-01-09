local meta = FindMetaTable("Player")
if not meta then return end

function meta:GetAiState()
    return self.AIState
end

function meta:SetAiState(index)
    self.AIState = index
end