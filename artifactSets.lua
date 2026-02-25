local RS = game:GetService("ReplicatedStorage")

local S = RS.common.packages.Knit.Services
local InvRF = S.InventoryService.RF
local EquipArtifactsLoadoutRF = InvRF.EquipArtifactsLoadout

local function equipWeightSet()
	EquipArtifactsLoadoutRF:InvokeServer(1)
end

local function equipDamageSet()
	EquipArtifactsLoadoutRF:InvokeServer(2)
end

local function equipSpeedSet()
	EquipArtifactsLoadoutRF:InvokeServer(3)
end

return {
	equipWeightSet = equipWeightSet,
	equipDamageSet = equipDamageSet,
	equipSpeedSet = equipSpeedSet,
}
