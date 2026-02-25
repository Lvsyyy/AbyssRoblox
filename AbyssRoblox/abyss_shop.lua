local VIM = game:GetService("VirtualInputManager")
local Buy = game:GetService("ReplicatedStorage"):WaitForChild("common"):WaitForChild("packages"):WaitForChild("Knit")
	:WaitForChild("Services"):WaitForChild("MerchantService"):WaitForChild("RF"):WaitForChild("Buy")

local T = workspace.Game.Merchants.Jeff.Folder.Table
local K = {"crimson shard"}

local function wanted(id)
	local name = (T[id..""].Item.SurfaceGui.Label.Text or ""):lower()
	for _,k in ipairs(K) do
		if name:find(k,1,true) then return true end
	end
end

task.spawn(function()
	while task.wait(10) do
		VIM:SendKeyEvent(true, Enum.KeyCode.LeftAlt, false, game)
		task.wait()
		VIM:SendKeyEvent(false, Enum.KeyCode.LeftAlt, false, game)

		for id=1,2 do
			if wanted(id) then
				Buy:InvokeServer("Jeff", id, 1)
				task.wait(0.15)
			end
		end
	end
end)
