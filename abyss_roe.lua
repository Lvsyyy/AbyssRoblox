local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")

local Common = RS:WaitForChild("common")
local KnitServices = Common:WaitForChild("packages"):WaitForChild("Knit"):WaitForChild("Services")

local FishPondRF = KnitServices:WaitForChild("FishPondService"):WaitForChild("RF")
local CollectAllRF = FishPondRF:WaitForChild("CollectAll")
local SellInventoryRF = KnitServices:WaitForChild("SellService"):WaitForChild("RF"):WaitForChild("SellInventory")
local EquipArtifactsLoadoutRF = KnitServices:WaitForChild("InventoryService"):WaitForChild("RF"):WaitForChild("EquipArtifactsLoadout")

local enabled = false
local nonce = 0

local function collect()
	pcall(function()
		CollectAllRF:InvokeServer()
	end)
end

local function sell()
	pcall(function()
		EquipArtifactsLoadoutRF:InvokeServer(4)
		SellInventoryRF:InvokeServer()
	end)
end

local function getUsageRatio()
	local main = pg:FindFirstChild("Main")
	local center = main and main:FindFirstChild("Center")
	local fishPond = center and center:FindFirstChild("FishPond")
	local pondMain = fishPond and fishPond:FindFirstChild("Main")
	local itemStash = pondMain and pondMain:FindFirstChild("itemStash")
	local itemWeight = itemStash and itemStash:FindFirstChild("ItemWeight")
	if not (itemWeight and itemWeight:IsA("TextLabel")) then
		return nil
	end

	local text = (itemWeight.Text or ""):gsub(",", "")
	local curStr, maxStr = text:match("([%d%.]+)%s*kg%s*/%s*([%d%.]+)%s*kg")
	local cur = tonumber(curStr)
	local maxv = tonumber(maxStr)
	if not cur or not maxv or maxv <= 0 then
		return nil
	end
	return cur / maxv
end

local function setEnabled(v)
	enabled = v == true
	nonce += 1
	local myNonce = nonce
	if not enabled then
		return
	end

	task.spawn(function()
		local nextActionAt = 0
		while enabled and myNonce == nonce do
			local ratio = getUsageRatio()
			if ratio and ratio >= 0.95 and tick() >= nextActionAt then
				collect()
				nextActionAt = tick() + 2
			end
			task.wait(0.2)
		end
	end)
end

local function getEnabled()
	return enabled
end

return {
	collect = collect,
	sell = sell,
	setEnabled = setEnabled,
	getEnabled = getEnabled,
}
