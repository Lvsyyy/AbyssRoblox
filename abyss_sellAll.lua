local RS = game:GetService("ReplicatedStorage")

local S = RS.common.packages.Knit.Services
local InvRF = S.InventoryService.RF
local SellRF = S.SellService.RF.SellInventory
local EquipArtifactsLoadoutRF = InvRF.EquipArtifactsLoadout

local function sellAll()
	EquipArtifactsLoadoutRF:InvokeServer(4)
	SellRF:InvokeServer()
end

return {
	sellAll = sellAll,
}
