local Buy = game:GetService("ReplicatedStorage").common.packages.Knit.Services.MerchantService.RF.Buy
local T = workspace.Game.Merchants.Jeff.Folder.Table
local K = {"crimson shard"}

while task.wait(10) do
	for id = 1, 2 do
		local n = T[id].Item.SurfaceGui.Label.Text:lower()
		for _, k in ipairs(K) do
			if n:find(k, 1, true) then
				Buy:InvokeServer("Jeff", id, 1)
				break
			end
		end
	end
end
