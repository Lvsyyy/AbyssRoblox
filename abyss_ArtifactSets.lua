local RS = game:GetService("ReplicatedStorage")

local S = RS.common.packages.Knit.Services
local InvRF = S.InventoryService.RF
local EquipArtifactsLoadoutRF = InvRF.EquipArtifactsLoadout

local function equipSet(index)
	EquipArtifactsLoadoutRF:InvokeServer(index)
end

local function equipWeightSet()
	equipSet(1)
end

local function equipDamageSet()
	equipSet(2)
end

local function equipSpeedSet()
	equipSet(3)
end

return {
	equipSet = equipSet,
	equipWeightSet = equipWeightSet,
	equipDamageSet = equipDamageSet,
	equipSpeedSet = equipSpeedSet,
}
